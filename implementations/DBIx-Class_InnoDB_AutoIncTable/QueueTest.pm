use 5.014; # implies strict
use warnings;
use utf8;

package Queue::Message {
    use base 'DBIx::Class::Core';
    use JSON;
    __PACKAGE__->table( 'queue_test_aitable' );
    __PACKAGE__->add_columns(qw( id transaction_id payload ));
    __PACKAGE__->set_primary_key( 'id' );
    __PACKAGE__->belongs_to( transaction => 'Queue::Transaction', { 'foreign.id' => 'self.transaction_id' } );
    __PACKAGE__->resultset_class( 'Queue::MessageBroker' );

    # To "accept" a message, we delete that row. This leaves the ORM object alone
    sub accept {
        my $self = shift;
        return $self->delete;
    }
    # To "reject" a message, we mark it as no longer part of a transaction
    sub reject {
        my $self = shift;
        return $self->update({ transaction_id => undef })
    }
    # Convenience method to automatically convert the JSON payload
    sub message {
        my $self = shift;
        return decode_json( $self->payload );
    }

    1; # Class returns true
}

package Queue::MessageBroker {
    use base 'DBIx::Class::ResultSet';
    use Class::Method::Modifiers;
    use JSON;
    __PACKAGE__->load_components(
        qw(Helper::ResultSet::Shortcut)
    );

    sub enqueue {
        my ($self,$message) = @_;
        # Returns unique message id
        return $self->create({ payload => encode_json( $message ) });
    }
    sub dequeue {
        my $self        = shift;
        my $wanted_msgs = shift || 1;
        # Get a transaction id
        my $trans_id = $self->related_resultset('transaction')->create({})
            or die 'Unable to get transaction id!';
        # Mark some messages as part of this transaction
        my $result = $self->order_by('id')
                          ->rows($wanted_msgs)
                          ->search({ transaction_id => undef })
                          ->update({ transaction_id => $trans_id });
        # Return marked messages
        return $self->search({ transaction_id => $trans_id })->all;
    }
    around 'count' => sub {
        my $orig = shift;
        my $self = shift;
        return $self->search({ transaction_id => undef })->$orig;
    };
}

package Queue::Transaction {
    use base 'DBIx::Class::Core';
    use JSON;
    __PACKAGE__->table( 'queue_transaction' );
    __PACKAGE__->add_columns( 'id' );
    __PACKAGE__->set_primary_key( 'id' );
    __PACKAGE__->might_have( message => 'Queue::Message', 'transaction_id' );
}

package Queue {
    use base 'DBIx::Class::Schema';
    __PACKAGE__->load_classes( 'Message', 'Transaction' );
    sub broker {
        my $class = shift;
        my %P = @_;
        $class->connect( $P{dbi_dsn}, $P{dbi_user}, $P{dbi_pass}, $P{dbi_opts} )->resultset('Message');
    }
}

1;

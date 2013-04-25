use 5.014; # implies strict
use warnings;
use utf8;

package Queue::Message {
    use base 'DBIx::Class::Core';
    use JSON;
    __PACKAGE__->table( 'queue_test_rand' );
    __PACKAGE__->add_columns(qw( id transaction_unique payload ));
    __PACKAGE__->set_primary_key( 'id' );
    __PACKAGE__->resultset_class( 'Queue::MessageBroker' );

    # To "accept" a message, we delete that row. This leaves the ORM object alone
    sub message_accept {
        my $self = shift;
        return $self->delete;
    }
    # To "reject" a message, we mark it as no longer part of a transaction
    sub message_reject {
        my $self = shift;
        return $self->update({ transaction_unique => undef })
    }
    # Convenience method to automatically convert the JSON payload
    sub message {
        my $self = shift;
        return decode_json( $self->payload );
    }
}

package Queue::MessageBroker {
    use base 'DBIx::Class::ResultSet';
    use JSON;
    __PACKAGE__->load_components(
        qw(Helper::ResultSet Helper::ResultSet::Shortcut)
    );

    sub message_queue {
        my ($self,$message) = @_;
        # Returns unique message id
        return $self->create({ payload => encode_json( $message ) });
    }
    sub message_dequeue {
        my $self        = shift;
        my $wanted_msgs = shift || 1;
        my $uniq        = int(rand(2**24));
        # Mark some messages as part of this transaction
        my $result = $self->order_by('id')
                          ->rows($wanted_msgs)
                          ->search({ transaction_unique => undef })
                          ->update({ transaction_unique => $uniq });
        # Return marked messages
        return $self->search({ transaction_unique => $uniq })->all;
    }
    sub message_count { shift->search({ transaction_unique => undef })->count };
}

package Queue {
    use base 'DBIx::Class::Schema';
    __PACKAGE__->load_classes( 'Message' );
    sub broker {
        my $class = shift;
        $class->connect( @_ )->resultset('Message');
    }
}

1;

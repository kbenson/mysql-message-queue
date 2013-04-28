package Queue {
    use 5.014; # implies strict
    use warnings;
    use utf8;
    use DBI;
    use JSON;

    my $queue_table = 'queue_test_aitable';
    my $trans_table = 'queue_transaction';
    sub broker {
        my $class = shift;
        my $self = bless {}, $class;
        $self->{dbi_connect_params} = [@_];
        $self->_dbh; # Connect
        return $self;
    }
    sub enqueue {
        my ($self,$payload) = @_;
        $payload = encode_json( $payload );
        my $dbh = $self->_dbh;
        my $sth ||= $dbh->prepare_cached("INSERT INTO `$queue_table` (payload) VALUES (?)");
        my $rv = $sth->execute($payload);
        my $id = $dbh->last_insert_id(undef, undef, undef, undef)
            or die 'No message id received!';
        return $id;
    }
    sub dequeue {
        my $self        = shift;
        my $wanted_msgs = shift || 1;
        die 'Invalid number of message' unless $wanted_msgs > 0;
        # Get transaction id
        my $dbh = $self->_dbh;
        my $trans_sth ||= $dbh->prepare_cached("INSERT INTO `$trans_table` VALUES ()");
        $trans_sth->execute;
        my $trans_id = $dbh->last_insert_id(undef, undef, undef, undef)
            or die 'No transaction id received!';
        # Update messages
        my $set_sth ||= $dbh->prepare_cached("UPDATE `$queue_table` SET `transaction_id` = ? WHERE `transaction_id` IS NULL LIMIT ?");
        $set_sth->execute($trans_id, $wanted_msgs);
        # Retrieve messages
        my $get_sth ||= $dbh->prepare_cached("SELECT `id`, `payload` FROM `$queue_table` WHERE `transaction_id` = ?");
        $get_sth->execute($trans_id);

        return map Message->new($_, $self), values $get_sth->fetchall_arrayref({})
    }
    sub count {
        shift->_dbh->selectrow_array("SELECT COUNT(*) FROM `$queue_table` WHERE `transaction_id` IS NULL");
    }
    sub message_accept {
        my ($self,$id) = @_;
        die 'No message id passed' unless defined $id;
        my $sth ||= $self->_dbh->prepare_cached("DELETE FROM `$queue_table` WHERE `id` = ?");
        $sth->execute($id);
        return 1;
    }
    sub message_reject {
        my ($self,$id) = @_;
        die 'No message id passed' unless defined $id;
        my $sth ||= $self->_dbh->prepare_cached("UPDATE `$queue_table` SET `transaction_id` = NULL WHERE `id` = ?");
        $sth->execute($id);
        return 1;
    }
    # Helpers
    sub _dbh {
        my $self = shift;
        $self->{dbh} = DBI->connect_cached( values $self->{dbi_connect_params} );
    }
}

package Message {
    use 5.014; # implies strict
    use warnings;
    use utf8;
    use JSON;

    sub new {
        $_[1]{_queue} = $_[2] || Queue->new;
        bless $_[1], $_[0];
    };
    sub id { $_[0]{id} }
    sub payload { $_[0]{payload} }
    sub message { decode_json( $_[0]{payload} ) }
    sub accept { $_[0]->{_queue}->message_accept($_[0]->{id}) }
    sub reject { $_[0]->{_queue}->message_reject($_[0]->{id}) }
};

1;

use 5.014; # implies strict
use warnings;
use utf8;

package Queue {
    use DBI;
    use JSON;
    my $queue_table = 'queue_test_rand';
    my $trans_table = 'queue_transaction';
    sub new {
        my $class = shift;
        my $self = bless {}, $_[0];
        $self->{dbi_connect_params} = [@_];
        $self->_dbh; # Connect
        return $self;
    }
    sub message_queue {
        my ($self,$payload) = @_;
        $payload = encode_json( $payload );
        my $sth ||= $self->{sth_cache}{queue}
                ||= $self->_dbh->prepare("INSERT INTO `$queue_table` (payload) VALUES (?)");
        my $rv = $sth->execute($payload);
        my $id = $self->_dbh->last_insert_id(undef, undef, undef, undef)
            or die 'No message id received!';
        return $id;
    }
    sub message_dequeue {
        my $self        = shift;
        my $wanted_msgs = shift || 1;
        die 'Invalid number of message' unless $wanted_msgs > 0;
        my $dbh = $self->_dbh;
        # Get transaction id
        my $uniq        = int(rand(2**24));
        # Update messages
        my $set_sth ||= $self->{sth_cache}{set_message_trans}
                    ||= $dbh->prepare("UPDATE `$queue_table` SET `transaction_unique` = ? WHERE `transaction_unique` IS NULL LIMIT ?");
        $set_sth->execute($uniq, $wanted_msgs);
        # Retrieve messages
        my $get_sth ||= $self->{sth_cache}{get_messages}
                    ||= $dbh->prepare("SELECT `id`, `payload` FROM `$queue_table` WHERE `transaction_unique` = ?");
        $get_sth->execute($uniq);

        return map Message->new($_), values $get_sth->fetchall_arrayref({})
    }
    sub message_count {
        my $self = shift;
        my $sth ||= $self->{sth_cache}{message_accept}
                ||= $self->_dbh->prepare("SELECT COUNT(*) FROM `$queue_table` WHERE `transaction_unique` IS NULL");
        $sth->execute;
        return $sth->fetchrow_array;
    }
    sub message_accept {
        my ($self,$id) = @_;
        die 'No message id passed' unless defined $id;
        my $sth ||= $self->{sth_cache}{message_accept}
                ||= $self->_dbh->prepare("DELETE FROM `$queue_table` WHERE `id` = ?");
        $sth->execute($id);
        return 1;
    }
    sub message_reject {
        my ($self,$id) = @_;
        die 'No message id passed' unless defined $id;
        my $sth ||= $self->{sth_cache}{message_accept}
                ||= $self->_dbh->prepare("UPDATE `$queue_table` SET `transaction_unique` = NULL WHERE `id` = ?");
        $sth->execute($id);
        return 1;
    }
    # Helpers
    sub _dbh {
        my $self = shift;
        return $self->{dbh} if $self->{dbh} and $self->{dbh}->ping;
        $self->{sth_cache} = {};
        $self->{dbh} = DBI->connect( $self->{dbi_connect_params} );
    }
}

package Message {
    use JSON;
    sub new {
        $_[1]{_queue} = $_[2] || Queue->new;
        bless $_[1], $_[0];
    };
    sub id { $_[0]{id} }
    sub payload { $_[0]{payload} }
    sub message { decode_json( $_[0]{payload} ) }
    sub message_accept { $_[0]->{_queue}->message_accept($_[0]->{id}) }
    sub message_reject { $_[0]->{_queue}->message_reject($_[0]->{id}) }
};

1;

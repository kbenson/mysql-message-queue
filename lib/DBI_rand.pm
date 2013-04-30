use 5.014; # implies strict
use warnings;
use utf8;

package Queue {
    use DBI;
    use JSON;
    my $queue_table = 'queue_test_rand';
    my $trans_table = 'queue_transaction';
    sub broker {
        my $class = shift;
        my $self = bless {}, $class;
        my %P = @_;
        $self->{dbh} = DBI->connect_cached( $P{dbi_dsn}, $P{dbi_user}, $P{dbi_pass}, $P{dbi_opts} );
        return $self;
    }
    sub enqueue {
        my ($self,$payload) = @_;
        $payload = encode_json( $payload );
        my $sth ||= $self->{dbh}->prepare_cached("INSERT INTO `$queue_table` (payload) VALUES (?)");
        my $rv = $sth->execute($payload);
        my $id = $self->{dbh}->last_insert_id(undef, undef, undef, undef)
            or die 'No message id received!';
        return $id;
    }
    sub dequeue {
        my $self        = shift;
        my $wanted_msgs = shift || 1;
        die 'Invalid number of message' unless $wanted_msgs > 0;
        # Get transaction id
        my $uniq        = int(rand(2**24));
        # Update messages
        my $set_sth ||= $self->{dbh}->prepare_cached("UPDATE `$queue_table` SET `transaction_unique` = ? WHERE `transaction_unique` IS NULL LIMIT ?");
        $set_sth->execute($uniq, $wanted_msgs);
        # Retrieve messages
        my $get_sth ||= $self->{dbh}->prepare_cached("SELECT `id`, `payload` FROM `$queue_table` WHERE `transaction_unique` = ?");
        $get_sth->execute($uniq);

        return map Message->new($_, $self), values $get_sth->fetchall_arrayref({})
    }
    sub count {
        shift->{dbh}->selectrow_array("SELECT COUNT(*) FROM `$queue_table` WHERE `transaction_unique` IS NULL");
    }
    sub message_accept {
        my ($self,$id) = @_;
        die 'No message id passed' unless defined $id;
        my $sth ||= $self->{dbh}->prepare_cached("DELETE FROM `$queue_table` WHERE `id` = ?");
        $sth->execute($id);
        return 1;
    }
    sub message_reject {
        my ($self,$id) = @_;
        die 'No message id passed' unless defined $id;
        my $sth ||= $self->{dbh}->prepare_cached("UPDATE `$queue_table` SET `transaction_unique` = NULL WHERE `id` = ?");
        $sth->execute($id);
        return 1;
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
    sub accept { $_[0]->{_queue}->message_accept($_[0]->{id}) }
    sub reject { $_[0]->{_queue}->message_reject($_[0]->{id}) }
};

1;

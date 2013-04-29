package Queue {
    use 5.014; # implies strict
    use warnings;
    use utf8;
    use Net::RabbitMQ;
    use DBI;
    use JSON;

    my $channel      = 1;
    my $queue_name  = 'queue_test';
    sub broker {
        my $class = shift;
        splice(@_, 0, 4); # First four params are for DBI
        my %defaults = @_;
        my $self = bless \%defaults, $class;
        $self->{channel}    ||= $channel++;
        say "channel: $self->{channel}";
        $self->{queue_name} ||= $queue_name;
        $self->{no_ack}     ||= 0;
        $self->{nrmq} = Net::RabbitMQ->new;
        $self->{nrmq}->connect("localhost", { user => "guest", password => "guest" });
        $self->{nrmq}->channel_open($self->{channel});
        $self->{nrmq}->queue_declare($self->{channel}, $self->{queue_name});
        $self->{consumer_tag} = $self->{nrmq}->consume(
            $self->{channel}, $self->{queue_name}, { no_ack => $self->{no_ack} }
        );
        return $self;
    }
    sub enqueue {
        my ($self,$payload) = @_;
        $payload = encode_json( $payload );
        $self->{nrmq}->publish($self->{channel}, $self->{queue_name}, $payload)
    }
    sub dequeue {
        my $self        = shift;
        my $wanted_msgs = shift || 1;
        my @messages;
        # Look into ->basic_qos and prefetch
        for (1 .. $wanted_msgs) {
            my $amqp = $self->{nrmq}->recv;
            next unless $amqp;
            push @messages, Message->new($amqp, $self);
        }
        return @messages;
    }
    sub count {
        my $self = shift;
        my ($name, $jobs, $consumer ) = $self->{nrmq}->queue_declare($self->{channel}, $self->{queue_name});
        return $jobs;
    }
    sub message_accept {
        my ($self,$id) = @_;
        return 1 if $self->{no_ack};
        die 'No message id passed' unless defined $id;
        $self->{nrmq}->ack($self->{channel}, $id);
        return 1;
    }
    sub message_reject {
        my ($self,$id) = @_;
        die 'No message id passed' unless defined $id;
        $self->{nrmq}->reject($self->{channel}, $id, 1);
        return 1;
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
    sub id { unpack 'I', $_[0]{delivery_tag} }
    sub payload { $_[0]{body} }
    sub message { decode_json( $_[0]{body} ) }
    sub accept { $_[0]->{_queue}->message_accept($_[0]->{delivery_tag}) }
    sub reject { $_[0]->{_queue}->message_reject($_[0]->{delivery_tag}) }
};

1;

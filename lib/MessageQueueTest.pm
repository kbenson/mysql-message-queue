
package MessageQueueTest {
    use 5.014;
    use warnings;
    use Time::HiRes qw(time);
    sub test_simple {
        my $broker = shift;
        my $time = time;

        # Queue 4 messages with a high-resolution timestamp for data
        $broker->message_queue({ time => time() }) for 1..4;
        my @messages;

        say 'Get one message, 4 -> 3';
        say $broker->message_count, ' messages available';
        @messages = $broker->message_dequeue;
        say scalar(@messages) . " received";
        printf("message: %d, time: %s\n", $_->id, $_->message->{time}) for @messages;
        $_->message_accept for @messages;
        print "\n";

        say 'Get two messages, but reject them, 3 -> 3';
        say $broker->message_count, ' messages available';
        @messages = $broker->message_dequeue(2);
        say scalar(@messages) . " received";
        printf("message: %d, time: %s\n", $_->id, $_->message->{time}) for @messages;
        $_->message_reject for @messages;
        print "\n";

        say 'Get two messages, 3 -> 1';
        say $broker->message_count, ' messages available';
        @messages = $broker->message_dequeue(2);
        say scalar(@messages) . " received";
        printf("message: %d, time: %s\n", $_->id, $_->message->{time}) for @messages;
        $_->message_accept for @messages;
        print "\n";

        say 'Try to get two messages when 1 available, 1 -> 0';
        say $broker->message_count, ' messages available';
        @messages = $broker->message_dequeue(2);
        say scalar(@messages) . " received";
        printf("message: %d, time: %s\n", $_->id, $_->message->{time}) for @messages;
        $_->message_accept for @messages;
        print "\n";

        return { simple => sprintf('%0.3f', time - $time) };
    }

    sub test_20x1_enqueue_dequeue {
        my $broker = shift;

        # Generate 1KiB payloads
        my $message = ['a'x(2**10)];

        my %times;

        # Enqueue 20k messages of payload
        $times{enqueue} = time;
        $broker->message_queue($message) for 1..20_000;
        $times{enqueue} = time - $times{enqueue};

        # Dequeue 20k messages
        $times{dequeue} = time;
        for (1..20_000) {
            my @messages = $broker->message_dequeue();
            $_->message_accept for @messages;
        }
        $times{dequeue} = time - $times{dequeue};

        return \%times;
    }
}

1;


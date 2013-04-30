
package MessageQueueTest {
    use 5.014;
    use warnings;
    use threads;
    use threads::shared;
    use Time::HiRes qw(time);
    use JSON;

    sub get_broker {
        require Queue;
        Queue->import;
        my $broker = Queue->broker;
    }

    sub simple {
        my %P = @_;
        my $broker = $P{broker_factory}();
        my $time = time;

        # Queue 4 messages with a high-resolution timestamp for data
        $broker->enqueue({ time => time() }) for 1..4;
        my @messages;

        say 'Get one message, 4 -> 3';
        say $broker->count, ' messages available';
        @messages = $broker->dequeue;
        say scalar(@messages) . " received";
        printf("message: %d, time: %s\n", $_->id, $_->message->{time}) for @messages;
        $_->accept for @messages;
        print "\n";

        say 'Get two messages, but reject them, 3 -> 3';
        say $broker->count, ' messages available';
        @messages = $broker->dequeue(2);
        say scalar(@messages) . " received";
        printf("message: %d, time: %s\n", $_->id, $_->message->{time}) for @messages;
        $_->reject for @messages;
        print "\n";

        say 'Get two messages, 3 -> 1';
        say $broker->count, ' messages available';
        @messages = $broker->dequeue(2);
        say scalar(@messages) . " received";
        printf("message: %d, time: %s\n", $_->id, $_->message->{time}) for @messages;
        $_->accept for @messages;
        print "\n";

        say 'Try to get two messages when 1 available, 1 -> 0';
        say $broker->count, ' messages available';
        @messages = $broker->dequeue(2);
        say scalar(@messages) . " received";
        printf("message: %d, time: %s\n", $_->id, $_->message->{time}) for @messages;
        $_->accept for @messages;
        print "\n";

        return {
            %P,
            timings => { total_time => sprintf('%0.3f', time - $time) },
        };
    }

    sub sequential {
        my %P = (
            messages        => 20_000,
            message_size    => 2**10,
            enqueue_clients => 1,
            dequeue_clients => 1,
            batch_size      => 1,
            @_, # Overriding defaults
        );
        die 'No broker factory passed!' unless $P{broker_factory} and ref $P{broker_factory} eq 'CODE';
        # This may lead to the odd message not being grabbed due to integer math, but it's okay
        my $per_enqueuer_messages = int( $P{messages} / $P{enqueue_clients} );
        my $per_dequeuer_messages = int( $P{messages} / $P{enqueue_clients} );

        # Generate 1KiB payloads
        my $message = ['a' x $P{message_size}];

        my $time = time;
        my %times = ( enqueue_max => 0, dequeue_max => 0);

        my @enqueuer_threads;
        push(@enqueuer_threads, threads->create(sub {
            my %times;
            my $enqueuer = $P{broker_factory}();

            # Wait for start sugnal
            say "Enqueuer waiting for start command";
            #{ lock($startlock); cond_timedwait($startlock, time()+10) or die 'Thread sync wait timeout!' }
            say "Enqueuer starting";

            # Enqueue 20k messages of payload
            my $threadtime = time;
            $enqueuer->enqueue($message) for 1..$per_enqueuer_messages;
            $threadtime = time - $threadtime;

            return $threadtime;
        })) for $P{enqueue_workers};

        $times{"enqueue$_"} = sprintf '%0.3f', $enqueuer_threads[$_-1]->join for 1 .. @enqueuer_threads;
        $times{enqueue_total} += $times{"enqueue$_"} for 1 .. @enqueuer_threads;
        $times{enqueue_max} = ($times{"enqueue$_"} > $times{enqueue_max} ? $times{"enqueue$_"} : $times{enqueue_max}) for 1 .. @enqueuer_threads;

        my @dequeuer_threads;
        push (@dequeuer_threads, threads->create(sub {
            my $dequeuer = $P{broker_factory}(channel => 2);

            # Wait for start signal
            say "Dequeuer waiting for start command";
            #{ lock($startlock); cond_timedwait($startlock, time()+10) or die 'Thread sync wait timeout!' }
            say "Dequeuer starting";

            # Dequeue 20k messages
            my $threadtime = time;
            for (1..$per_dequeuer_messages) {
                my @messages = $dequeuer->dequeue($P{batch_size});
                $_->accept for @messages;
            }
            $threadtime = time - $threadtime;

            return $threadtime;
        })) for $P{dequeue_workers};

        $times{"dequeue$_"} = sprintf '%0.3f', $dequeuer_threads[$_-1]->join for 1 .. @dequeuer_threads;
        $times{dequeue_total} += $times{"dequeue$_"} for 1 .. @dequeuer_threads;
        $times{dequeue_max} = ($times{"dequeue$_"} > $times{dequeue_max} ? $times{"dequeue$_"} : $times{dequeue_max}) for 1 .. @dequeuer_threads;

        $times{total_time} = sprintf('%0.3f', time - $time);

        return {
            %P,
            timings => \%times,
        };
    }

    sub simultaneous {
        my %P = (
            messages        => 20_000,
            message_size    => 1024,
            enqueue_clients => 1,
            dequeue_clients => 1,
            batch_size      => 1,
            @_, # Overriding defaults
        );
        die 'No broker factory passed!' unless $P{broker_factory} and ref $P{broker_factory} eq 'CODE';
        # This may lead to the odd message not being grabbed due to integer math, but it's okay
        my $per_enqueuer_messages = int( $P{messages} / $P{enqueue_clients} );
        my $per_dequeuer_messages = int( $P{messages} / $P{enqueue_clients} );

        my $startlock : shared;

        # Generate 1KiB payload
        my $message = ['a' x $P{message_size}];
        say "Message serializes to " . length(encode_json($message)) . " bytes";

        my $time = time;
        my %times = ( enqueue_max => 0, dequeue_max => 0);

        my @enqueuer_threads;
        push(@enqueuer_threads, threads->create(sub {
            my %times;
            my $enqueuer = $P{broker_factory}();

            # Wait for start sugnal
            say "Enqueuer waiting for start command";
            #{ lock($startlock); cond_timedwait($startlock, time()+10) or die 'Thread sync wait timeout!' }
            say "Enqueuer starting";

            # Enqueue 20k messages of payload
            my $threadtime = time;
            $enqueuer->enqueue($message) for 1..$per_enqueuer_messages;
            $threadtime = time - $threadtime;

            return $threadtime;
        })) for $P{enqueue_workers};

        my @dequeuer_threads;
        push (@dequeuer_threads, threads->create(sub {
            my $dequeuer = $P{broker_factory}(channel => 2);

            # Wait for start signal
            say "Dequeuer waiting for start command";
            #{ lock($startlock); cond_timedwait($startlock, time()+10) or die 'Thread sync wait timeout!' }
            say "Dequeuer starting";

            # Dequeue 20k messages
            my $threadtime = time;
            for (1..$per_dequeuer_messages) {
                my @messages = $dequeuer->dequeue($P{batch_size});
                $_->accept for @messages;
            }
            $threadtime = time - $threadtime;

            return $threadtime;
        })) for $P{dequeue_workers};

    #sleep(2);
    #lock($startlock);
    #$startlock = 1;
    #say "Sending start command";
    #cond_broadcast($startlock);

        $times{"enqueue$_"} = sprintf '%0.3f', $enqueuer_threads[$_-1]->join for 1 .. @enqueuer_threads;
        $times{enqueue_total} += $times{"enqueue$_"} for 1 .. @enqueuer_threads;
        $times{enqueue_max} = ($times{"enqueue$_"} > $times{enqueue_max} ? $times{"enqueue$_"} : $times{enqueue_max}) for 1 .. @enqueuer_threads;

        $times{"dequeue$_"} = sprintf '%0.3f', $dequeuer_threads[$_-1]->join for 1 .. @dequeuer_threads;
        $times{dequeue_total} += $times{"dequeue$_"} for 1 .. @dequeuer_threads;
        $times{dequeue_max} = ($times{"dequeue$_"} > $times{dequeue_max} ? $times{"dequeue$_"} : $times{dequeue_max}) for 1 .. @dequeuer_threads;

        $times{total_time} = sprintf('%0.3f', time - $time);

        return {
            %P,
            timings => \%times,
        };
    }
}

package MessageQueueTest::Tests {
    sub simple { return MessageQueueTest::simple( broker_factory => shift ) }

    sub sequential_1x1_200_32KiB {
        return MessageQueueTest::sequential(
            broker_factory  => shift,
            messages        => 200,
            message_size    => 32*1024,
        );
    }
    sub sequential_4x1_200_32KiB {
        return MessageQueueTest::sequential(
            broker_factory  => shift,
            messages        => 200,
            message_size    => 32*1024,
            enqueue_clients => 4,
        );
    }
    sub sequential_1x4_200_32KiB {
        return MessageQueueTest::sequential(
            broker_factory  => shift,
            messages        => 200,
            message_size    => 32*1024,
            dequeue_clients => 4,
        );
    }
    sub sequential_4x4_200_32KiB {
        return MessageQueueTest::sequential(
            broker_factory  => shift,
            messages        => 200,
            message_size    => 32*1024,
            enqueue_clients => 4,
            dequeue_clients => 4,
        );
    }

    sub simultaneous_4x1_20k_1024 {
        return MessageQueueTest::simultaneous(
            broker_factory  => shift,
            messages        => 20_000,
            message_size    => 1024,
            enqueue_clients => 1,
            dequeue_clients => 1,
            batch_size      => 1,
        );
    }
    sub simultaneous_1x1_200k_32 {
        return MessageQueueTest::simultaneous(
            broker_factory  => shift,
            messages        => 200_000,
            message_size    => 32,
            enqueue_clients => 1,
            dequeue_clients => 1,
            batch_size      => 1,
        );
    }
    sub simultaneous_1x1_200_32KiB {
        return MessageQueueTest::simultaneous(
            broker_factory  => shift,
            messages        => 200,
            message_size    => 32*1024,
            enqueue_clients => 1,
            dequeue_clients => 1,
            batch_size      => 1,
        );
    }
}

1;


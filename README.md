mysql-message-queue
===================

A message queue in MySQL implementation, with alternate strategies benchmarked in Perl

Rules
=====

Each subdirectory in implementations must contain a perl module called
Queue.pm, such that the directory can be used with "use lib" and provides
a pair of classes, Queue and Message with the following API:

Queue:
    broker($dsn, $dbuser, $dbpass, $opts):
        Provides a broker instance to call the following methods on.
        Accepts DBI connect params.
    message_queue($message):
        Queue message for dequeuing by client. The $message should be
        any structure cabable of being accurately serialized to and from
        JSON.
    message_dequeue($count):
        Dequeue up to the requested number of messages.  The $count param
        will be 1 if omitted.  Returned messages should be instances of
        the Method class.
    messge_count():
        Provide a count of messages within the queue.  This method can be
        considered optional.

Message:
    message_accept():
        Mark message accepted (removed from queue)
    message_reject():
        Release message back to the queue for another client

Notes: A message should not be able to be accepted by multiple clients.

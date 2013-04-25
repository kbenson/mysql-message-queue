mysql-message-queue
===================

A message queue in MySQL implementation shootout, with implementation
strategies benchmarked in Perl.

Rules
=====

Each subdirectory in implementations must contain an SQL schema file
called schema.sql which will be run on the test DB to set up the SQL
environment and a Perl module called QueueTest.pm that implements two
classes, Queue and Message. The module must function such that the
directory can be specified with "use lib" and we can "use QueueTest"
and are provided with the pair of classes.

The Queue and Message classes should implement the following API:

### Queue

* #### broker($dsn, $dbuser, $dbpass, $opts)
  Provides a broker instance to call the following methods on.
  Accepts DBI connect params.

* #### message_queue($message)
  Queue message for dequeuing by client. The $message should be
  any structure capable of being accurately serialized to and from
  JSON.

* #### message_dequeue($count)
  Dequeue up to the requested number of messages.  The $count param
  will be 1 if omitted.  Returned messages should be instances of
  the Method class.

* #### messge_count()
  Provide a count of messages within the queue.  This method can be
  considered optional.


### Message

* #### message_accept()
  Mark message accepted (removed from queue)

* #### message_reject()
  Release message back to the queue for another client


### Notes/Conditions:
0. A message should not be able to be accepted by multiple clients.
0. At this time persistence is assumed, later we will test both
   persistent and transient configurations, and there will be a way
   to tag an implementation as supporting one or both configurations.
0. The message_count method of Queue will not be used in benchmarks,
   so need not be implemented with speed in mind. It is included here
   as a useful method for testing.
0. We assume that Perl 5 can stand in for any language of the same
   class (Python, Ruby, PHP), since the bottlenext should be the DB.


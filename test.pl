#!/usr/bin/env perl
use 5.014;
use warnings;
use DBI;
use lib 'lib';
use MessageQueueTest;
$|++;

sub usage {
    my $msg = shift;
    $msg .= "\n" if $msg;
    $msg .=
<<EOUSAGE;

Usage: $0 IMPLEMENTATION TEST

    ./test.pl ./implementations/Net-RabbitMQ simple

To list implementations or tests, you can use the list sub-command.

    $0 list [all]
    $0 list implementations
    $0 list tests

EOUSAGE
}

sub list {
    my $list = shift || 'all';
    die usage('Invalid list command') if $list and not $list =~ /\Aimplementations|tests|all\Z/;
    if ($list =~ /\Aimplementations|all\Z/) {
        my @implementations = glob './implementations/*';
        my $implementations = "Implementations:\n\t" . join("\n\t", @implementations) . "\n";
        say $implementations;
    }

    if ($list =~ /\Atests|all\Z/) {
        my @tests = sort do { no strict 'refs'; grep { defined &{"MessageQueueTest::Tests\::$_"} } keys %{"MessageQueueTest::Tests\::"} };
        my $tests = "Tests:\n\t" . join("\n\t", @tests) . "\n";
        say $tests;
    }

    return 0;
}

# Make sure test dir has required files
my $test_dir = shift or die usage();
exit list(shift) if $test_dir eq 'list';
my $test_type = shift or die usage();
die "$test_dir does not exist!" unless -d $test_dir;
die "$test_dir is not readable!" unless -r $test_dir;
die "$test_dir/QueueTest.pm does not exist!" unless -r "$test_dir/QueueTest.pm";
die "$test_dir/schema.sql does not exist!" unless -r "$test_dir/schema.sql";

my $test_base = 'implementations';
my $dbhost = 'localhost';
my $dbname = 'queuetest';
my $dbuser = 'queuetest_user';
my $dbpass = 'queuetest_pass';
my @dbi_params = (
    "DBI:mysql:database=$dbname;host=$dbhost;mysql_socket=/var/lib/mysql/mysql.sock",
    $dbuser, $dbpass, { PrintError => 0, RaiseError => 1, AutoCommit => 1 }
);

# Make new DB instance
say 'Creating database instance';
say "If you experience any problems, try running:\n" .
    "GRANT ALL ON $dbname.* TO '$dbuser'\@'localhost' IDENTIFIED BY '$dbpass';";
my $drh = DBI->install_driver('mysql');
$drh->func('dropdb', $dbname, '127.0.0.1', $dbuser, $dbpass, 'admin'); # Can fail
$drh->func('createdb', $dbname, '127.0.0.1', $dbuser, $dbpass, 'admin')
    or die $DBI::errstr;
my $dbh = DBI->connect(@dbi_params) or die $DBI::errstr;
my $mysql_import_output = qx{mysql -h '$dbhost' -D '$dbname' -u '$dbuser' --password='$dbpass' < $test_dir/schema.sql};
die "Error creating schema: \n\n$mysql_import_output" unless $?>>8 == 0;

# Load QueueTest
say 'Loading Queue implementation';
unshift @INC, $test_dir;
require QueueTest;
QueueTest->import;

my $broker_factory = sub { Queue->broker(@dbi_params) };

my $test_sub = MessageQueueTest::Tests->can($test_type)
    or die "No such test: 'MessageQueueTest::Tests::$test_type'";
say "Starting test $test_type";
my $times = $test_sub->($broker_factory);

use Data::Dumper; print Dumper $times;

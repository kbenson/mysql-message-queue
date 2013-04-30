#!/usr/bin/env perl
use 5.014;
use warnings;
use Getopt::Long;
use threads;
use DBI;
use Try::Tiny;
use Capture::Tiny qw(:all);
use Data::Dumper;
use lib 'lib';
use MessageQueueTest;
$|++;

sub usage {
    my $msg = shift;
    $msg .= "\n" if $msg;
    $msg .=
<<EOUSAGE;

Usage: $0 IMPLEMENTATION TEST

    ./test.pl [OPTIONS] -t TYPE -l LIBDIR

    --type, -t      Test type: simple, sequential, simultaneous
    --libdir, -l    Lib dir containing QueueTest.pm implementation
    --size, -s      Message size.  Default: 1024
    --messages, -m  Total messages
    --batch, -b     How many messages to send/receive at once
    --enqueuers, -e Numer of enqueue client prodcesses
    --dequeuers, -d Number of dequeue client processes
    --count, -c     Number of times to run test.
    --moduleopt opt=val     Additional options to pass to Queue->broker()

    Default module options are as follows:
        dbi_driver=mysql
        dbi_host=localhost
        dbi_user=queuetest_user
        dbi_pass=queuetest_pass
        dbi_name=queuetest
        dbi_opts= { PrintError => 0, RaiseError => 1, AutoCommit => 1 }
        rmq_no_ack=0,

EOUSAGE
}

my $test_count = 1;
my %O = (
    type            => 'simple',
    message_size    => 1024,
    messages        => 20_000,
    batch_size      => 1,
    enqueue_clients => 1,
    dequeue_clients => 1,
    verbose         => 0,
);
# Defaults for queue broker instantiation
my %MODOPTS = (
    dbi_driver  => 'mysql',
    dbi_host    => 'localhost',
    dbi_user    => 'queuetest_user',
    dbi_pass    => 'queuetest_pass',
    dbi_name    => 'queuetest',
    dbi_opts    => { PrintError => 0, RaiseError => 1, AutoCommit => 1 },
    rmq_no_ack  => 0,
);
Getopt::Long::Configure ("bundling");
GetOptions(
    'verbose|v'     => \$O{verbose},
    'libdib|l=s'    => \$O{libdir},
    'type|t=s'      => \$O{type}, # simple, sequential, simultaneous
    'size|s=i'      => \$O{message_size},
    'messages|m=i'  => \$O{messages},
    'batch|b=i'     => \$O{batch_size},
    'enqueuers|e=i' => \$O{enqueue_clients},
    'dequeuers|d=i' => \$O{dequeue_clients},
    'count|c=i'     => \$test_count,
    'moduleopt=s%'  => \%MODOPTS,
) or die usage();
$MODOPTS{dbi_dsn} ||= "DBI:mysql:database=$MODOPTS{dbi_name};host=$MODOPTS{dbi_host};mysql_socket=/var/lib/mysql/mysql.sock";
MessageQueueTest->can($O{type}) or die "Unknown test type: '$O{type}'";

sub D(@) {
    return unless $O{verbose};
    printf @_;
    print "\n" unless $_[-1] =~ /\n\z/;
}

# Make sure test dir has required files
die usage('No libdir passed!') unless $O{libdir};
$O{libdir} = [glob $O{libdir}];
die 'libdir does not expand to any paths!' unless values $O{libdir};
for my $libdir (values $O{libdir}) {
    die "$libdir does not exist!"                unless -d $libdir;
    die "$libdir is not readable!"               unless -r $libdir;
    die "$libdir/QueueTest.pm does not exist!"   unless -r "$libdir/QueueTest.pm";
}

my %ALLTESTS = ( options => \%O, module_options => \%MODOPTS, tests => {} ),;
for my $libdir (values $O{libdir}) {
    say "Testing $libdir";
    try { $ALLTESTS{tests}{$libdir} = threads->create(sub {

        # Make new DB instance if he have a schema
        if (-r "$libdir/schema.sql") {
            D "Creating database instance and isntalling $libdir/schema.sql";
            my $message_ip = $MODOPTS{dbi_host} =~ /\Alocalhost|\Q127.0.0.1\E\Z/ ? $MODOPTS{dbi_host} : '$TESTCLIENT_IP_HERE';
            my $grant_message = "GRANT ALL ON $MODOPTS{dbi_name}.* TO '$MODOPTS{dbi_user}'\@'$message_ip' IDENTIFIED BY '$MODOPTS{dbi_pass}';";
            D "If you experience any problems, try running:\n$grant_message";

            my $drh = DBI->install_driver('mysql');
            $drh->func('dropdb',   $MODOPTS{dbi_name}, $MODOPTS{dbi_host}, $MODOPTS{dbi_user}, $MODOPTS{dbi_pass}, 'admin'); # Can fail
            $drh->func('createdb', $MODOPTS{dbi_name}, $MODOPTS{dbi_host}, $MODOPTS{dbi_user}, $MODOPTS{dbi_pass}, 'admin') or die $DBI::errstr;
            my $dbh = DBI->connect($MODOPTS{dbi_dsn}, $MODOPTS{dbi_user}, $MODOPTS{dbi_pass}, $MODOPTS{dbi_opts}) or die $DBI::errstr;
            my $mysql_import_output = qx|mysql -h '$MODOPTS{dbi_host}' -D '$MODOPTS{dbi_name}' -u '$MODOPTS{dbi_user}' --password='$MODOPTS{dbi_pass}' < $libdir/schema.sql|;
            die "Error creating schema: \n\n$mysql_import_output\n\nPerhaps try running the following in MySQL:\n\t$grant_message" unless $?>>8 == 0;
        }
        else { say "NO schema found at $libdir/schema.sql"; }

        # Load QueueTest
        D "Loading Queue implementation: $libdir";
        unshift @INC, $libdir;
        require QueueTest;
        QueueTest->import;

        my $broker_factory = sub { Queue->broker(%MODOPTS) };

        my $test_sub = MessageQueueTest->can($O{type})
            or die "Unknown test type: '$O{type}'";

        D "Starting test";
        my @THISLIB;
        for my $i (1 .. $test_count) {
            my ($stdout,$stderr,$times) = capture { $test_sub->( broker_factory => $broker_factory, %O ) };
            $times->{iteration} = $i;
            #use Data::Dumper; print Dumper $times;
            push( @THISLIB, $times->{timings} );
        }

        # We are done with this lib
        shift @INC;

        return \@THISLIB;
    })->join };
}

print Dumper(\%ALLTESTS);


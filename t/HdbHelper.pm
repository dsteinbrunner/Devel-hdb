package HdbHelper;

use strict;
use warnings;

use File::Basename;
use IO::Socket;

use Exporter 'import';
our @EXPORT = qw( start_test_program );

use File::Temp;

my $out_fh;
sub start_test_program {
    my $pkg = caller;
    my $in_fh;
    {   no strict 'refs';
        $in_fh = *{ $pkg . '::DATA' };
    }
    $out_fh = File::Temp->new('devel-hdb-test-XXXX');

    {
        # Localize $/ for slurp mode
        # Localize $. to avoid die messages including 
        local($/, $.);
        $out_fh->print(<$in_fh>);
        $out_fh->close();
    }

    my $libdir = File::Basename::dirname(__FILE__). '/../../../lib';

    my $port = $ENV{DEVEL_HDB_PORT} = pick_unused_port();
    Test::More::note("Using port $ENV{DEVEL_HDB_PORT}\n");
    my $cmdline = $^X . " -I $libdir -d:hdb " . $out_fh->filename;
    Test::More::note("running $cmdline");
    my $pid = fork();
    if ($pid) {
        Test::More::note("pid $pid");
        sleep(0);
    } elsif(defined $pid) {
        exec($cmdline);
        die "Running child process failed: $!";
    } else {
        die "fork failed: $!";
    }

    eval "END { Test::More::note('Killing pid $pid'); kill $pid }";
    return ("http://localhost:${port}/");
}

# Pick a port not in use by the system
# It's kind of a hack, in that some other process _could_
# pick the same port between the time we close this one and the
# debugged program starts up.
# It also relies on the fact that HTTP::Server::PSGI specifies
# Reuse => 1 when it opens the port
sub pick_unused_port {
    my $s = IO::Socket::INET->new(Listen => 1, LocalAddr => 'localhost', Proto => 'tcp');
    my $port = $s->sockport();
    return $port;
}

1;
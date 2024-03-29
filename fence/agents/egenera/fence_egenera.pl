#!/usr/bin/perl

use Getopt::Std;
use IPC::Open3;

my $ME = $0;

END {
  defined fileno STDOUT or return;
  close STDOUT and return;
  warn "$ME: failed to close standard output: $!\n";
  $? ||= 1;
}

# WARNING!! Do not add code bewteen "#BEGIN_VERSION_GENERATION" and 
# "#END_VERSION_GENERATION"  It is generated by the Makefile

#BEGIN_VERSION_GENERATION
$RELEASE_VERSION="";
$REDHAT_COPYRIGHT="";
$BUILD_DATE="";
#END_VERSION_GENERATION

# Get the program name from $0 and strip directory names
$_=$0;
$|=1;
s/.*\///;
my $pname = $_;

$esh="/opt/panmgr/bin/esh";

sub usage 
{
	print "Usage:\n";
	print "\n";
	print "$pname [options]\n";
	print "\n";
	print "Options:\n";
	print "  -c <string>      cserver\n";
	print "  -h               help\n";
	print "  -l <string>      lpan\n";
	print "  -o <string>      Action: reboot (default), off, on or status\n";
	print "  -p <string>      pserver\n";
	print "  -u <string>      username (default=root)\n";
	print "  -f <seconds>     Wait X seconds before fencing is started\n";
	print "  -q               quiet mode\n";
	print "  -V               version\n";
	
	exit 0;
}

sub fail
{
	($msg)=@_;
	print $msg."\n" unless defined $opt_q;
	$t->close if defined $t;
	exit 1;
}

sub fail_usage
{
	($msg)=@_;
	print STDERR $msg."\n" if $msg;
	print STDERR "Please use '-h' for usage.\n";
	exit 1;
}


sub version
{
	print "$pname $RELEASE_VERSION $BUILD_DATE\n";
	print "$REDHAT_COPYRIGHT\n" if ( $REDHAT_COPYRIGHT );

	exit 0;
}

sub print_metadata
{
print '<?xml version="1.0" ?>
<resource-agent name="fence_egenera" shortdesc="I/O Fencing agent for the Egenera BladeFrame" >
<longdesc>
fence_egenera  is  an I/O Fencing agent which can be used with the Egenera BladeFrame. It logs into a control blade (cserver) via ssh and operates on a process    ing  blade  (pserver) identified by the pserver name and the logical process area network (LPAN) that it is in. fence_egenera requires that ssh keys have been setup so that the fence_egenera  does not require a password to authenticate. Refer to ssh(8) for more information on setting up ssh keys.
</longdesc>
<vendor-url>http://www.bull.com</vendor-url>
<parameters>
        <parameter name="action" unique="0" required="1">
                <getopt mixed="-o [action]" />
                <content type="string" default="reboot" />
                <shortdesc lang="en">Fencing Action</shortdesc>
        </parameter>
        <parameter name="cserver" unique="0" required="1">
                <getopt mixed="-c [cserver]" />
                <content type="string"  />
                <shortdesc lang="en">The cserver to ssh to. cserver can be in the form user@hostname to specify a different user to login as.</shortdesc>
        </parameter>
        <parameter name="pserver" unique="0" required="1">
                <getopt mixed="-p [pserver]" />
                <content type="string"  />
                <shortdesc lang="en">The pserver to operate on.</shortdesc>
        </parameter>
        <parameter name="user" unique="0" required="1">
                <getopt mixed="-u [name]" />
                <content type="string" default="root" />
                <shortdesc lang="en">Login Name</shortdesc>
        </parameter>
        <parameter name="lpan" unique="0" required="1">
                <getopt mixed="-l [lpan]" />
                <content type="string"  />
                <shortdesc lang="en">The lpan to operate on.</shortdesc>
        </parameter>
        <parameter name="delay" unique="0" required="0">
                <getopt mixed="-f [seconds]" />
                <content type="string" default="0"/>
                <shortdesc lang="en">Wait X seconds before fencing is started</shortdesc>
        </parameter>
        <parameter name="help" unique="0" required="0">
                <getopt mixed="-h" />           
                <content type="string"  />
                <shortdesc lang="en">Display help and exit</shortdesc>                    
        </parameter>
</parameters>
<actions>
        <action name="on" />
        <action name="off" />
	<action name="reboot" />
        <action name="status" />
        <action name="metadata" />
</actions>
</resource-agent>
';
}

if (@ARGV > 0) 
{
	getopts("c:hl:o:p:u:qVf:") || fail_usage ;

	usage if defined $opt_h;
	version if defined $opt_V;

	fail_usage "Unkown parameter." if (@ARGV > 0);


	$cserv  = $opt_c if defined $opt_c;
	$lpan   = $opt_l if defined $opt_l;
	$pserv  = $opt_p if defined $opt_p;
	$action = $opt_o if defined $opt_o;
	$user   = $opt_u if defined $opt_u;
	$delay  = $opt_f if defined $opt_f;
} 
else 
{
	get_options_stdin();
} 

if (((defined $opt_o) && ($opt_o =~ /metadata/i)) || ((defined $action) && ($action =~ /metadata/i))) {
	print_metadata();
	exit 0;
}

$action = "reboot" unless defined $action;
$user = "root" unless defined $user;

fail "failed: no cserver defined" unless defined $cserv;
fail "failed: no lpan defined" unless defined $lpan;
fail "failed: no pserver defined" unless defined $pserv;

fail "failed: unrecognised action: $action"
	unless $action =~ /^(off|on|reboot|status|pblade)$/i;

sub get_options_stdin
{
	my $opt;
	my $line = 0;
	while( defined($in = <>) )
	{
		$_ = $in;
		chomp;

		# strip leading and trailing whitespace
		s/^\s*//;
		s/\s*$//;

		# skip comments
		next if /^#/;

	        $line+=1;
		$opt=$_;
		next unless $opt;

		($name,$val)=split /\s*=\s*/, $opt;

		if ( $name eq "" )
		{
			print STDERR "parse error: illegal name in option $line\n";
			exit 2;
		} 

		elsif ($name eq "agent" )
		{
			# DO NOTHING -- this field is used by fenced 
		}

		elsif ($name eq "cserver" ) 
		{
			$cserv = $val;
		} 

		elsif ($name eq "lpan" ) 
		{
			$lpan = $val;
		} 

		elsif ($name eq "pserver" ) 
		{
			$pserv = $val;
		} 

		elsif ($name eq "action" ) 
		{
			$action = $val;
		} 

		elsif ($name eq "esh" ) 
		{
			$esh = $val;
		} 
		elsif ($name eq "user" )
		{
			$user = $val;
		}
		elsif ($name eq "delay" )
		{
			$delay = $val;
		}
	}
}

# _pserver_query_field -- query the state of the pBlade or Status field
# and return it's value in $_.  
# Return 0 on success, or non-zero on error
sub _pserver_query_field
{
	my ($field,$junk) = @_;

	if ($field ne "pBlade" && $field ne "Status")
	{
		$_="Error _pserver_query_field: unknown field of type '$field'";
		return 1;
	}

	my $val;

	my $cmd = "ssh -l $user $cserv $esh pserver $lpan/$pserv";
	my $pid = open3 (\*WTR, \*RDR,\*RDR, $cmd)
		or die "error open3(): $!";

	while(<RDR>)
	{
		chomp;
		my $line = $_;
		my @fields = split /\s+/,$line;

		if ($fields[0] eq "Error:")
		{
			$val=$line;
			print "Debug ERROR: $val\n";
			last;
		}
		elsif ($fields[0] eq $pserv)
		{
			if ( $field eq "Status" ) 
			{
				$val=$fields[1];
			}
			elsif ($field eq "pBlade" )
			{
				# grrr... Status can be "Shutting down"
				if ($fields[1] ne "Shutting")
				{
					$val=$fields[3];
				}
				else
				{
					$val=$fields[4];
				}
			}
		}
	}

	close WTR;
	close RDR;
	
	waitpid $pid,0;
	my $rtrn = $?>>8;
	$_=$val if defined $val;
	return $rtrn;
}

# return the pBlade of an lpan/pserver in $_.  
# Return 0 on success or non=zero on error
sub pserver_pblade
{
	_pserver_query_field "pBlade";
}

# return the Status of an lpan/pserver in $_.  
# Return 0 on success or non=zero on error
sub pserver_status
{
	_pserver_query_field "Status";
}

# boot an lpan/pserver.  
# Return 0  if the status is "Booted" or "Booting" or non-zero on failure.
# Continue checking the value until the status is "Boot" or "Booting" or
# until a timeout of 120 seconds has been reached.
sub pserver_boot
{
	my $rtrn=1;

	# It seems it can take a while for a pBlade to 
	# boot sometimes.  We shall wait for 120 seconds
	# before giving up on a node returning failure
	for (my $trys=0; $trys<120; $trys++)
	{
		last if (pserver_status != 0);

		my $status = $_;
		if ( $status eq "Booted"  || $status eq "Booting")
		{
			$rtrn=0;
			last;
		}

		if(pserver_pblade)
		{
			die "error getting pBlade info";
		}

		# Is there any harm in sending this command multiple times?
		my $cmd = "ssh -l $user $cserv $esh pserver -b $lpan/$pserv";
		my $pid = open3 (\*WTR, \*RDR,\*RDR, $cmd)
			or die "error open3(): $!";

		close WTR;
		close RDR;

		waitpid $pid,0;
		$rtrn = $?>>8;

		sleep 1;
	}
	return $rtrn;
}

# boot an lpan/pserver.  
# Return 0  if the status is "Shutdown" or non-zero on failure.
# Continue checking the value until the status is "Shutdown" or
# until a timeout of 20 seconds has been reached.
sub pserver_shutdown
{
	my $rtrn=1;
	local *egen_log;
	open(egen_log,">>/@LOGDIR@/fence_egenera.log");
	print egen_log "Attempting shutdown at ".`date`."\n";
	for (my $trys=0; $trys<20; $trys++)
	{
		last if (pserver_status != 0);


		my $status = $_;
                print egen_log "shutdown: $trys    $status\n";
		if (/^Shutdown/)
		{
			$rtrn=0;
			last;
		}
		elsif (/^Shutting/)
		{
			# We are already in the process of shutting down.
			# do I need to do anything here?  
			# We'll just wait for now
		}
    elsif (/^Booting/)
    {
       # Server is already on the way back up. Do nothing
       $rtrn=0;
       last;
    }
		elsif (/^Booted\(KDB\)/ || /^Debugging/ )
		{
			print egen_log "shutdown: crash dump being performed. Waiting\n";
			$rtrn=0;
			last;
		}
		else
		{
			if (pserver_pblade)
			{
				die "error getting pBlade info: $_";
			}

			# is there any harm in sending this command multiple 
			# times?
			my $cmd = "ssh -l $user $cserv $esh blade -s $_";
                        print egen_log "shutdown: $cmd  being called, before open3\n";
			my $pid = open3 (\*WTR, \*RDR,\*RDR, $cmd)
				or die "error open3(): $!";
                        print egen_log "shutdown: after calling open3\n";
                        @outlines = <RDR>;
                        print egen_log "shutdown: Open3 result: ", @outlines, "\n";

			close WTR;
			close RDR;

			waitpid $pid,0;
			$rtrn = $?>>8;
		}

		sleep 1;
	}
        print egen_log "shutdown: Returning from pserver_shutdown with return code $rtrn\n";
	return $rtrn;
}


$_=$action;
if (/^status$/i)
{
	if (pserver_status==0)
	{
		print "$lpan/$pserv is $_\n" unless defined $opt_q;
		exit 0;
	}
	else
	{
		fail "failed to get status of $lpan/$pserv: $_";
	}
}
elsif (/^pblade$/i)
{
	if (pserver_pblade==0)
	{
		print "$lpan/$pserv is $_\n" unless defined $opt_q;
		exit 0;
	}
	else
	{
		fail "failed to get pblade of $lpan/$pserv: $_";
	}
}
elsif (/^off$/i)
{
	sleep ($delay) if defined($delay);
	if (pserver_shutdown==0)
	{
		print "success: $lpan/$pserv has been shutdown\n" 
			unless defined $opt_q;
		exit 0;
	}
	else
	{
		fail "failed to shutdown $lpan/$pserv";
	}
}
elsif (/^on$/i)
{
	if (pserver_boot==0)
	{
		print "success: $lpan/$pserv has been turned on\n" 
			unless defined $opt_q;
		exit 0;
	}
	else
	{
		fail "failed to turn on $lpan/$pserv";
	}
}
elsif (/^reboot$/i)
{
	sleep ($delay) if defined($delay);
	if (pserver_shutdown!=0)
	{
		fail "failed to shutdown $lpan/$pserv";
	}

	if (pserver_boot==0)
	{
		print "success: $lpan/$pserv has been rebooted\n" 
			unless defined $opt_q;
		exit 0;
	}
	else
	{
		fail "failed to turn on $lpan/$pserv";
	}
}
else
{
	die "unknown action: $action";
}

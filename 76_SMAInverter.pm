###############################################################
# 
#
#  Copyright notice
#
#  Published according Creative Commons : Attribution-NonCommercial-ShareAlike 3.0 Unported (CC BY-NC-SA 3.0)
#  Details: https://creativecommons.org/licenses/by-nc-sa/3.0/
#
#  Credits:
#  - based on 77_SMASTP.pm by Volker Kettenbach with following credits:
#    - based on an Idea by SpenZerX and HDO
#    - Waldmensch for various improvements
#    - sbfspot (https://sbfspot.codeplex.com/)
#  - written by Thomas Schoedl (sct14675) with inputs from Volker, waldmensch and DS_starter
# 
#  Description:
#  This is an FHEM-Module for SMA Inverters.
#  Tested on Sunny Tripower 6000TL-20 and Sunny Island 4.4
#
#  Requirements:
#  This module requires:
#  - Perl Module: IO::Socket::INET
#  - Perl Module: Datime
#
#
###############################################################

package main;

use strict;
use warnings;
use IO::Socket::INET;      
use DateTime;

# Global vars
my $globname = "SMAInverter";

# Sleep Mode variables
my $default_starthour = "05:00";
my $starthour = 5;
my $startminute = 0;
my $default_endhour = "22:00";
my $endhour = 22;
my $endminute = 0;
my $suppress_night_mode = 0;
# Reporting (=Reading) detail level: 
# 0 - Standard (only power and energy), 1 - More details(including current and voltage), 2 - All Data
my $detail_level = 0;
# General enabling of the module
my $modulstate_enabled = 0;
# Alarm levels based on power
my ($alarm_value1,$alarm_value2,$alarm_value3);
# protocol related
my $mysusyid = 233;								# random number, has to be different from any device in local network
my $myserialnumber = 123321123;		# random number, has to be different from any device in local network
my $target_susyid = 0xFFFF;				# 0xFFFF is any susyid
my $target_serial = 0xFFFFFFFF;		# 0xFFFFFFFF is any serialnumber
my $default_target_susyid = 0xFFFF;				# 0xFFFF is any susyid
my $default_target_serial = 0xFFFFFFFF;		# 0xFFFFFFFF is any serialnumber
my $pkt_ID = 0x8001;						# Packet ID

# Inverter Data fields
my $inv_susyid = 0;
my $inv_serial = 0;

#Return values
my $r_OK = 0;		# Everything OK
my $r_FAIL = 1;	# Operation failed


###################################
sub SMAInverter_Initialize($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $hval;
	my $mval;

	$hash->{DefFn}     = "SMAInverter_Define";
	$hash->{UndefFn}   = "SMAInverter_Undef";
	$hash->{AttrList}  = "suppress-night-mode:0,1 " .
						"starttime " .
						"endtime " .
						"enable-modulstate:0,1 " .
						"alarm1-value " .
						"alarm2-value " .
						"alarm3-value " .
						"interval " . 
						"detail-level:0,1,2 " .
						$readingFnAttributes;
	$hash->{AttrFn}   = "SMAInverter_Attr";
	
	if ($attr{$name}{"starttime"})
	{
		($hval, $mval) = split(/:/,$attr{$name}{"starttime"});
	}
	else
	{
		($hval, $mval) = split(/:/,$default_starthour);
	}
	$starthour = int($hval);
	$startminute = int($mval);
	
	if ($attr{$name}{"endtime"})
	{
		($hval, $mval) = split(/:/,$attr{$name}{"endtime"});
	}
	else
	{
		($hval, $mval) = split(/:/,$default_endhour);
	}
	$endhour = int($hval);
	$endminute = int($mval);

	$suppress_night_mode = ($attr{$name}{"suppress-night-mode"}) ? $attr{$name}{"suppress-night-mode"} : 0;
	$modulstate_enabled = ($attr{$name}{"enable-modulstate"}) ? $attr{$name}{"enable-modulstate"} : 0;
	$detail_level = ($attr{$name}{"detail-level"}) ? $attr{$name}{"detail-level"} : 0;
	
	$alarm_value1 = ($attr{$name}{"alarm1-value"}) ? $attr{$name}{"alarm1-value"} : 0;
	$alarm_value2 = ($attr{$name}{"alarm2-value"}) ? $attr{$name}{"alarm2-value"} : 0;
	$alarm_value3 = ($attr{$name}{"alarm3-value"}) ? $attr{$name}{"alarm3-value"} : 0;
	
	Log3 $name, 0, "$name: Started with sleepmode from $endhour:$endminute - $starthour:$startminute";
}

###################################
sub is_Sleepmode()
{
	# Build 3 DateTime Objects to make the comparison more robust
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
	my $dt_startdate = DateTime->new(year=>$year+1900,month=>$mon+1,day=>$mday,hour=>$starthour,minute=>$startminute,second=>0,time_zone=>'local');
	my $dt_enddate = DateTime->new(year=>$year+1900,month=>$mon+1,day=>$mday,hour=>$endhour,minute=>$endminute,second=>0,time_zone=>'local');
	my $dt_now = DateTime->now(time_zone=>'local');

	# Return of any value != 0 means "sleeping"
	if ($dt_now >= $dt_enddate || $dt_now <= $dt_startdate)
	{
		# we have reached normal sleepmode now
		return 1;
	}
	else
	{
		# no sleepmode
		return 0;
	}
}

###################################
sub SMAInverter_Define($$)
{
	my ($hash, $def) = @_;
	my @a = split("[ \t][ \t]*", $def);

	return "Wrong syntax: use define <name> SMAInverter <inv-userpwd> <inv-hostname/inv-ip > " if ((int(@a) < 4) and (int(@a) > 5));

	my $name	= $a[0];
	$hash->{NAME} 	= $name;
	$hash->{LASTUPDATE}=0;
	$hash->{INTERVAL} = 60;

	# SMAInverter	= $a[1];
	my ($IP,$Host,$Caps);

	my $Pass = $a[2];		# to do: check 1-12 Chars

	# extract IP or Hostname from $a[4]
	if ( $a[3] ~~ m/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/ )
	{
	if ( $1 <= 255 && $2 <= 255 && $3 <= 255 && $4 <= 255 )
		{
			$Host = int($1).".".int($2).".".int($3).".".int($4);
		}
	}
	
	if (!defined $Host)
	{
		if ( $a[3] =~ /^([A-Za-z0-9_.])/ )
		{
			$Host = $a[3];
		}
	}
	
	if (!defined $Host)
	{
		return "Argument:{$a[3]} not accepted as Host or IP. Read device specific help file.";
	}

	$hash->{Pass} = $Pass; 
	$hash->{Host} = $Host;

	InternalTimer(gettimeofday()+5, "SMAInverter_GetStatus", $hash, 0);	# refresh timer start

	return undef;
}

#####################################
sub SMAInverter_Undef($$)
{
	my ($hash, $name) = @_;
	RemoveInternalTimer($hash); 
	Log3 $hash, 0, "$name: Undefined!";
	return undef;
}

###################################
sub SMAInverter_Attr(@)
{
	my ($cmd,$name,$aName,$aVal) = @_;
  	# $cmd can be "del" or "set"
	# $name is device name
	# aName and aVal are Attribute name and value
	my $hash = $defs{$name};
	
	my $hval;
	my $mval;

	if (($aName eq "starttime" || $aName eq "endtime") && not ($aVal =~ /^([0-1]?[0-9]|[2][0-3]):([0-5][0-9])$/))
	{
		return "value $aVal invalid"; # no correct time format hh:mm
	}
	
	if ($aName eq "enable-modulstate")
	{
		$modulstate_enabled  = ($cmd eq "set") ?  int($aVal) : 0;
		Log3 $name, 3, "$name: Set $aName to $aVal";
	}
	
	if ($aName eq "alarm1-value")
	{
		$alarm_value1  = ($cmd eq "set") ?  int($aVal) : 0;
		Log3 $name, 3, "$name: Set $aName to $aVal";
	}
	
	if ($aName eq "alarm2-value")
	{
		$alarm_value2  = ($cmd eq "set") ?  int($aVal) : 0;
		Log3 $name, 3, "$name: Set $aName to $aVal";
	}
	
	if ($aName eq "alarm3-value")
	{
		$alarm_value3  = ($cmd eq "set") ?  int($aVal) : 0;
		Log3 $name, 3, "$name: Set $aName to $aVal";
	}
	
	if ($aName eq "starttime")
	{
		if ($cmd eq "set")
		{
			($hval, $mval) = split(/:/,$aVal);
		}
		else
		{
			($hval, $mval) = split(/:/,$default_starthour);
		}
		if (int($hval) < 12)
		{
			$starthour = int($hval);
			$startminute = int($mval);
		}
		else
		{
			return "$name: Attr starttime must be set smaller than 12:00! Not set to $starthour:$startminute";
		}
		
		Log3 $name, 3, "$name: Attr starttime is set to " . sprintf("%02d:%02d",$starthour,$startminute);
	}
	
	if ($aName eq "endtime")
	{
		if ($cmd eq "set")
		{
			($hval, $mval) = split(/:/,$aVal);
		}
		else
		{
			($hval, $mval) = split(/:/,$default_endhour);
		}
		
		if (int($hval) > 12)
		{
			$endhour = int($hval);
			$endminute = int($mval);
		}
		else
		{
			return "$name: Attr endtime must be set larger than 12:00! Not set to $endhour:$endminute";
		}
		
		Log3 $name, 3, "$name: Attr endtime is set to " . sprintf("%02d:%02d",$endhour,$endminute);
	}
	
	if ($aName eq "suppress-night-mode") 
	{
		$suppress_night_mode = ($cmd eq "set") ? $aVal : 0;
		Log3 $name, 3, "$name: Set $aName to $aVal";
	}

	if ($aName eq "detail-level") 
	{
		$detail_level = ($cmd eq "set") ? $aVal : 0;
		Log3 $name, 3, "$name: Set $aName to $aVal";
	}
		
	if ($aName eq "interval") 
	{
		if ($cmd eq "set") 
		{
			$hash->{INTERVAL} = $aVal;
			Log3 $name, 3, "$name: Set $aName to $aVal";
		}
	} else 
	{
		$hash->{INTERVAL} = "60";
		Log3 $name, 3, "$name: Set $aName to $aVal";
	}
	return undef;
}

#####################################
sub SMAInverter_GetStatus($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $interval = $hash->{INTERVAL};
	
	# For logging events set the module name
	$globname = $name;
	
	if(SMA_logon($hash->{Host}, $hash->{Pass}) eq $r_OK)
	{
			Log3 $globname, 5, "$globname: Logged in now";
			
			# nothing more to do, just log out
			SMA_logout($hash->{Host});
	} else
	{
	}
	
	InternalTimer(gettimeofday()+$interval, "SMAInverter_GetStatus", $hash, 1);
}

####################################
sub SMA_logon($$)
{
	my $host = $_[0];
	my $pass = $_[1];
	my $cmdheader = "534D4100000402A00000000100";
	my $pktlength = "3A";		# length = 58 for logon command
	my $esignature = "001060650EA0";
	my $cmd = "";
	my $timestmp = "";
	my $myID = "";
	my $target_ID = "";
	my $spkt_ID = "";
	my $cmd_ID = "";
	my ($socket,$data,$size);
	
	use constant MAXBYTES => scalar 100;
	
	#Encode the password
	my $encpasswd = "888888888888888888888888"; # template for password	
	for my $index (0..length $pass )	# encode password
	{
		substr($encpasswd,($index*2),2) = substr(sprintf ("%lX", (hex(substr($encpasswd,($index*2),2)) + ord(substr($pass,$index,1)))),0,2);
	}
	
	# Get current timestamp in epoch format (unix format)
	$timestmp = ByteOrderLong(sprintf("%08X",int(time())));
	
	# Define own ID and target ID and packet ID
	$myID = ByteOrderShort(substr(sprintf("%04X",$mysusyid),0,4)) . ByteOrderLong(sprintf("%08X",$myserialnumber));
	$target_ID = ByteOrderShort(substr(sprintf("%04X",$target_susyid),0,4)) . ByteOrderLong(sprintf("%08X",$target_serial));
	$pkt_ID = 0x8001;	# Reset to 0x8001
	$spkt_ID = ByteOrderShort(sprintf("%04X",$pkt_ID));
	
	#Logon command
	$cmd_ID = "0C04FDFF" . "07000000" . "84030000";  # Logon command + User group "User" + (maybe) Timeout
	
	#build final command to send
	$cmd = $cmdheader . $pktlength . $esignature . $target_ID . "0001" . $myID . "0001" . "00000000" . $spkt_ID . $cmd_ID . $timestmp . "00000000" . $encpasswd . "00000000";

	# flush after every write
	$| = 1; 				
	
	# Create Socket and check if successful
	$socket = new IO::Socket::INET (PeerHost => $host, PeerPort => 9522, Proto => 'udp',); # open Socket

	if (!$socket) { 															
		# in case of error
		Log3 $globname, 1, "$globname: ERROR. Can't open socket to inverter: $!";
		return $r_FAIL;
	};

	# Send Data
	$data = pack("H*",$cmd);
	$socket->send($data);
	Log3 $globname, 4, "$globname: Send login to $host on Port 9522 with password $pass ";
	Log3 $globname, 5, "$globname: Send: $cmd ";
	
	# Receive Data and do a first check regarding length
	eval 
	{
		local $SIG{ALRM} = sub { die "alarm time out" };
		alarm 5;
		# receive data
		$socket->recv($data, MAXBYTES) or die "recv: $!";					
		$size = length($data);

		# check if something was received
		if (defined $size)															
		{
			my $received = unpack("H*", $data);
			Log3 $globname, 5, "$globname: Received: $received";
			
		}
		
		alarm 0;
		1;																	
	} or Log3 $globname, 1, "$globname query timed out";
	
	# Nothing received -> exit loop
	if (not defined $size)															
	{
		Log3 $globname, 1, "$globname: Nothing received...";
		# send: cmd_logout
		SMA_logout($host);
		$socket->close();
		return $r_FAIL;
	} else
	{
		# We have received something!
		
		if ($size > 62)
		{
			# Check all parameters of answer
			my $r_susyid = unpack("V*", substr $data, 20, 2);
			my $r_serial = unpack("V*", substr $data, 22, 4);
			my $r_pkt_ID = unpack("V*", substr $data, 40, 2);
			my $r_cmd_ID = unpack("V*", substr $data, 42, 4);
			my $r_error  = unpack("V*", substr $data, 36, 4);
			if (($r_susyid ne $mysusyid) || ($r_serial ne $myserialnumber) || ($r_pkt_ID ne $pkt_ID) || ($r_cmd_ID ne 0xFFFD040D) || ($r_error ne 0))
			{
				# Response does not match the parameters we have sent, maybe different target
				Log3 $globname, 1, "$globname: Inverter answer does not match our parameters.";
				Log3 $globname, 5, "$globname: Request/Response: SusyID $mysusyid/$r_susyid, Serial $myserialnumber/$r_serial, Packet ID $pkt_ID/$r_pkt_ID, Command 0xFFFD040D/$r_cmd_ID, Error $r_error";
				# send: cmd_logout
				SMA_logout($host);
				$socket->close();
				return $r_FAIL;
			}
			# ******************************************************************
			
		} else
		{
			Log3 $globname, 1, "$globname: Format of inverter response does not fit.";
			# send: cmd_logout
			SMA_logout($host);
			$socket->close();
			return $r_FAIL;
		}
	}
	
	# All seems ok, logged in! 
	$socket->close();	
	return $r_OK;
}

####################################
sub SMA_logout($)
{
	my $host = $_[0];
	my $cmdheader = "534D4100000402A00000000100";
	my $pktlength = "22";		# length = 34 for logout command
	my $esignature = "0010606508A0";
	my $cmd = "";
	my $timestmp = "";
	my $myID = "";
	my $target_ID = "";
	my $spkt_ID = "";
	my $cmd_ID = "";
	my ($socket,$data,$size);
	
	# Define own ID and target ID and packet ID
	$myID = ByteOrderShort(substr(sprintf("%04X",$mysusyid),0,4)) . ByteOrderLong(sprintf("%08X",$myserialnumber));
	$target_ID = ByteOrderShort(substr(sprintf("%04X",$target_susyid),0,4)) . ByteOrderLong(sprintf("%08X",$target_serial));
	# Increasing Packet ID
	$pkt_ID = $pkt_ID + 1;	
	$spkt_ID = ByteOrderShort(sprintf("%04X",$pkt_ID));
	
	#Logout command
	$cmd_ID = "0E01FDFF" . "FFFFFFFF";  # Logout command

	#build final command to send
	$cmd = $cmdheader . $pktlength . $esignature . $target_ID . "0003" . $myID . "0003" . "00000000" . $spkt_ID . $cmd_ID . "00000000";

	# flush after every write
	$| = 1; 				
	
	# Create Socket and check if successful
	$socket = new IO::Socket::INET (PeerHost => $host, PeerPort => 9522, Proto => 'udp',); # open Socket

	if (!$socket) { 															
		# in case of error
		Log3 $globname, 1, "$globname: ERROR. Can't open socket to inverter: $!";
		return $r_FAIL;
	};
	
	$socket->close();	
	return $r_OK;	
}

####################################
sub ByteOrderShort($)
{
	my $input = $_[0];
	my $output = "";
	$output = substr($input, 2, 2) . substr($input, 0, 2);
	return $output;
}

####################################
sub ByteOrderLong($)
{
	my $input = $_[0];
	my $output = "";
	$output = substr($input, 6, 2) . substr($input, 4, 2) . substr($input, 2, 2) . substr($input, 0, 2);
	return $output;
}
1;

=pod

=begin html

<a name="SMAInverter"></a>
<h3>SMAInverter</h3>

Module for the integration of a SMA Inverter build by SMA over it's Speedwire (=Ethernet) Interface.<br>
Tested on Sunny Tripower 6000TL-20, 10000-TL20 and 10000TL-10 with Speedwire/Webconnect Piggyback.
*** To be rewritten...

=end html_DE

#!/usr/bin/perl
# AUTHOR:           Kristoffer Marshall  (aka Kristoff)
# WEBSITE:          http://www.hackingforkids.com
# GOOGLE PLUS:     https://plus.google.com/118073020950935552634 
#
# DESCRIPTION:
#   This is some code to unlock one's xscreensaver
#   whenever an RFID tag is detected.
#
# DEPENDENCIES:
#   * An RFID reader that outputs to USB
#   * xscreensaver
#   * Perl module Device::SerialPort
#   * xdotool
#   For Fedora/RHEL/CentOS users:
#     yum install perl-Device-SerialPort xdotool xscreensaver
#
# NOTES:
#   * Make sure the USB path is correct
#   * Make sure the baud, parity, and stop bits are correct
#   * Replace "password" below with your password.
#   * If you're positive you have the correct start and stop bytes
#       and never see them read, check your baud rate. 
#   * Increase $LOCK_INTERVAL if you would like more time for the
#     device to pull for your RFID tag. This is useful if your
#     reader's output is getting to your computer slower. So if
#     this script works most of the time but sometimes locks,
#     try increasing this value. This is also useful if you want
#     some more leeway before the computer locks or unlocks. Say
#     you moved your RFID tag for a split second and want time to
#     reposition it.
#
# TODO:
#   * Automatically detect the correct USB port
#   * Possibly have an encrypted password file, or some sort of key system
#   * Automatically "learn" RFID tags to minimize setup
#   * Accept command line flags
#   * Use a string as the password
#
# The serial values here should work with the following:
# URL to Parallax USB RFID Card Reader (#28340): 
#   http://www.parallax.com/sites/default/files/downloads/28140-28340-RFID-Reader-Documentation-v2.2.pdf

use Device::SerialPort;

# You can set the sound variables to blank if you don't want sound. Otherwise, modify them to point to directories with wave files.
my $LOCK_SOUND = 'aplay -q `find /home/YOURUSERNAME/sounds/lock/*.wav -type f | shuf -n 1`&';
my $UNLOCK_SOUND = 'aplay -q `find /home/YOURUSERNAME/sounds/unlock/*.wav -type f | shuf -n 1`&';

my $LOCK_COMMAND    = $LOCK_SOUND . ' xscreensaver-command --lock &> /dev/null';
my $UNLOCK_COMMAND  = $UNLOCK_SOUND . ' xdotool type "$(printf "YOURPASSWORDHERE\n")"; xdotool key KP_Enter';

my @TRUSTED_IDS      = ('0a3834312463454442', '0a3823435333338412'); # Unique IDs of your RFID cards
my $LOCK_INTERVAL   = 500; # Lock timeout in loop iterations
my $LOCK_MESSAGE = 'No trusted RFID tag detected. Locking screen.';
my $UNLOCK_MESSAGE = 'Trusted RFID tag detected. Unlocking screen.';


#######=- Unique to your RFID reader. Find the specs if you're unsure.
my $port = Device::SerialPort->new("/dev/ttyUSB0"); # You will most likely need to change this
my $START_BYTE       = '0a'; 
my $STOP_BYTE        = '0d';
$port->databits(8);
$port->baudrate(2400);
$port->parity("none");
$port->stopbits(1);

# These may be tweaked per system. The program will work without them, but the system will
# poll as fast as it can and CPU will be driven up significantly (like use a whole core).
$port->read_char_time(0);
$port->read_const_time(3); 
#######=-


my $count = 0;
my $blanked = 0;
my $unlocked = 0;

print "Started stealth screensaver locking mechanism. Remove your RFID tag and the screen will lock.\n";
while(1) {
    &watchToLock;
    &watchToUnlock;
}


#################################################
#  ___      _                 _   _             
# / __|_  _| |__ _ _ ___ _  _| |_(_)_ _  ___ ___
# \__ \ || | '_ \ '_/ _ \ || |  _| | ' \/ -_|_-<
# |___/\_,_|_.__/_| \___/\_,_|\__|_|_||_\___/__/
#  
#################################################

sub watchToUnlock {
    #print "Watching to unlock...\n";
    open (IN, "xscreensaver-command -watch |");
    while (<IN>) { # Change this to watch the RFID reader instead
        if(&watchForTrustedID) {
            system $UNLOCK_COMMAND;
            print $UNLOCK_MESSAGE . "\n";
            return 1;
         }
    }
}

sub watchToLock {
    if(&watchForTrustedID(1) == 1) {
        print $LOCK_MESSAGE . "\n";
        system $LOCK_COMMAND;
    }
}

# Exits the loop and returns "1" when the ID is not detected or "2" when it is.
# Pass it a "1" to put it into "watch to lock" mode.
sub watchForTrustedID {
    my $lockMode = shift;
    #print "Watching for trusted ID. Lock mode: $lockMode\n";
    my $readTag = 0;
    my $tagID;
    my $counter = 0;
    while (1) {
        if($lockMode == 1){
            $counter++;

            # Useful for tweaking the "count" value. It resets once the correct ID is read.
            #print "Count: $counter\n";
            if($counter > $LOCK_INTERVAL) {
                return 1;
            }
        }
        my $char = $port->read(255);
        if ($char) {
            $char =~ s/(.)/ sprintf '%02x', ord $1 /seg;
            if ($char eq $START_BYTE){
                $readTag = 1;
            }
            if ($char eq $STOP_BYTE){
                $readTag = 0;
                #print "ID: $tagID\n";
                if($tagID ~~ @TRUSTED_IDS){
                    if($lockMode == 1) {
                        $counter = 0;
                    } else { return 2; }
                }
                $tagID = ""; 
            }
            if ($readTag) {
                $tagID = $tagID . $char;
            }
        }
    }
}


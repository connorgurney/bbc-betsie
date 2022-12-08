#!/usr/local/bin/perl -Tw

# parser.pl v 1.5.12
# by wayne.myers@bbc.co.uk (et al)
# Enormous thanks to:
# Chay Palton, Damion Yates, George Auckland,
# Dan Tagg, T.V. Raman, Mark Foster, Peter Burden,
# Jack Evans, Steve at wels.net, Gene D., Maurice Walshe
# Mark A. Rowe and many others.

# parser.pl aka BETSIE is Copyright 1998 - 2001 BBC Digital Media
# See LICENCE for full licence details
# See README for more information
# See ChangeLog for version changes

# modules
use Socket;
use strict;

# variables

my $version = "1.5.12";	# version number
my @x = ();         	# all the lines of the html page we're parsing
my $contents = "";  	# @x concatenated
my $inpath = "";    	# path_info string from which we get the rest
my $qs;                 # query string, used for authorisation process
my $root = "";      	# domain of the page we are looking at
my $path = "";      	# path of the page we are looking at
my $file = "";      	# name of the file we are looking at
my $postdata = "";  	# POST method data
my $method = "GET"; 	# $method remains this way unless we get POST data
my $length = -1;    	# but is the length of content if any greater in a POST
my $count;		# counter for main request loop
my $httptype;		# http type of request
my $code;		# http return code
my $msg;		# http message
my $newurl;		# used to store redirect target
my $tag;		# used to store meta redirect tags
my $loop_flag;		# flag used to make sure we get the right page
my $script_flag;    	# flag used to see if we are in script tags or not
my $ws_flag;		# flag used to minimise unnecessary white space
my $set = 0;            # is 1 if we want the settings page
my $body; 		# the body tag
my $cookies;            # cookies we want to pass on to other server
my @setcookies;         # cookies server wants us to pass onto user
my $header;             # the http header we want to send the browser
my $extraheaders;       # extra headers to send the server on requests
my $nocontenttype = 1;  # flag unset when content type is printed
my $basic_realm;        # contains strin
my $set_auth = 0;       # flag set when required authorisation is provided


# VARIABLES YOU MIGHT WANT TO CHANGE:

my $pathtoparser = "http://$ENV{'SERVER_NAME'}$ENV{'SCRIPT_NAME'}";
my $selfnuke = "(?:$pathtoparser|$ENV{'SCRIPT_NAME'})"; # used to eliminate textonly links to self
my $maxpost = 65536; # is maximum number of bytes in a POST
my $parsehome = "http://www.bbc.co.uk/education/betsie/";
my $name = $ENV{'SCRIPT_NAME'};		# name of this file
$name =~ s/^.*\/(\w\.+)$/$1/;
my $agent = $ENV{'HTTP_USER_AGENT'};	# pretend to be the calling browser

my $allowchars = '[a-zA-Z0-9_.\-\/\#\?\&\=\%\~\+\:]'; # allowed characters
my $alarm = 20;  # number of seconds before we time out

# variables for colour/font settings etc
# be sure to amend make_body() if you amend them
my $setstr = "/0005";	# is default string for settings.
my $chsetstr = "/1005";  # string used for default change settings page
# next five arrays are for each set of colour options. feel free to add to or amend these.
my @bg    = ('#000000', '#FFFFFF', '#0000FF', '#FFFFCC');
my @text  = ('#FFFF00', '#000000', '#FFFFFF', '#000000');
my @link  = ('#00FFFF', '#0000FF', '#FFFFCC', '#0000FF');
my @vlink = ('#00CCFF', '#0000CC', '#FFFF99', '#0000CC');
my @alink = ('#FFFF00', '#000000', '#FFFFFF', '#000000');
# ten fonts. again, you can change these if you like
my @font_face = ("Verdana, Arial", "Times", "Courier", "Helvetica", "Arial",
		 "Bookman Old Style", "Geneva", "Chicago", "Courier New", "System");

# VARIABLES YOU MUST SUPPLY:

my $localhost = ""; #"www.bbc.co.uk";  # name of the actual machine which is localhost
                                  # (not necessarily same as server name if its virtual)

my $parsecontact = "wayne.myers\@bbc.co.uk";

my @safe = qw (	bbc.co.uk
		beeb.com
		bbcworldwide.com
		bbcresources.com
		bbcshop.com
		radiotimes.com
		open.ac.uk
		open2.net
		freebeeb.net
		);

# VARIABLES YOU (PROBABLY) DON'T WANT TO TOUCH:

my ($rec_test) = $pathtoparser =~ /^http:\/(.*)$/;	# var to solve recursion problem

# Set alarm handler (comment this out on systems that can't handle it)
alarm $alarm;
$SIG{ALRM} = \&alarm;

# main loop

$|=1;

# handle POST requests

if ($ENV{'REQUEST_METHOD'} eq "POST") {
    
    $length = $ENV{'CONTENT_LENGTH'};
    
    if ($length > $maxpost) {
	$x[0] = "Too much data for POST method.";
	error();
	exit;
    }
    
    if ($length) {
	
	read(STDIN, $postdata, $length, 0);
	$method = "POST";
	
    }

}

# take path info or referer allowing easy linking in...
$inpath = $ENV{'PATH_INFO'} || $ENV{'HTTP_REFERER'};
# strip http/ftp/gopher etc scheme if present (ie came from referer)
$inpath =~ s/^\w+:\///;
	       
# Uncomment the following ugly hack for servers that don't do PATH_INFO properly 
# (if you couldn't do alarm above, you probably need this too :( )
# $inpath =~ s/^.*?$name//;

# get query string
$qs = $ENV{'QUERY_STRING'} || "";

if (($inpath !~ /^$allowchars+$/) ||
    ($inpath =~ /\.\./) ||
    ($qs !~ /^$allowchars*$/) ||
    ($qs =~ /\.\./)) {
    $x[0] = "Unknown error";
    error();
    exit 0;
}



# beat recursive betsie bug #1
$inpath =~ s/^$rec_test//i;

# get optional settings string
$inpath =~ s!^(\/\d{4})\/!\/!;
$setstr = $1 || $setstr;  # is already initialised to '/0005'
if (length $setstr != 5) { $setstr = "/0005"; }
$chsetstr = $setstr;
$chsetstr =~ s/^\/(\d)/\/1/;
if ($1 eq "1") { $set = 1;};

($root, $path, $file) = urlcalc($inpath);

unless (safe("http:\/\/$root")) {
    $x[0] = "<a href=\"http:\/\/$root$path$file\">http:\/\/$root$path$file<\/a> not on safe list. Sorry";
    error();
    exit;
}

$cookies = $ENV{'HTTP_COOKIE'} || $ENV{'COOKIE'} || "";

# turn any Betsie-auth cookie into an Authorization header
if ($cookies =~ s/Betsie-auth=([A-Za-z0-9\+\=\/]*?)\;//s) {

    $extraheaders = "Authorization: Basic $1\n";
    $set_auth = 1;

}

# if query string contains our betsie-pi parameter
# this is an attempt to authorise ourselves on a page
# if it isn't really, the following will simply fail...
if($postdata =~ /betsie-pi=/) {

    # set a cookie with the auth string
    my ($authcook, $authloc) = make_auth_cookie_and_loc($file);
    # redirect to ourselves with the proper url

    print "Set-Cookie: Betsie-auth=$authcook;\n";
    print "Content-Type: text/html\n\n"; 
    print <<HTML;

<html>
<head>
<meta HTTP-EQUIV="Refresh" CONTENT="0; URL=$pathtoparser/$authloc">
</head>
<body>
<p>Logging in. Please follow <a href="$pathtoparser/$authloc">this link</a>.
</body>
</html>

HTML

    exit 0;

}


$loop_flag = 0;
$count = 0;

 LOOP: while ($loop_flag == 0) {
     
     $count++;
     if ($count == 9) {
	 $x[0] = "Too many times through the loop.";
	 error();
	 exit;
     }
     
     if ($qs ne "") { $file .= "\?$qs" }
     
     @x = graburl($root, $path . $file);

     $contents=join '', @x;
     
     # handle http codes
     # 3xx we follow the redirect
     # anything other than 200 is an error.
     
     ($httptype, $code, $msg) = split /\s+/, $x[0];
     
     if ($code =~ /^3\d\d/) {
	 $contents =~ s/^.*Location:\s+(\S+)\s.*$/$1/s;
	 $newurl = $contents;
	 redir();
	 next LOOP;
     }
     
     if ($code !~ /200|401/) {
	 error();
	 exit;
     }
     
     # check for autoredirects of all sorts
     
     if ($contents =~ /(<meta[^>]*?http-equiv[^>]*?refresh[^>]*?>)/is) {
	 $tag = $1;
	 unless ($tag =~ /content=\"\d{3,}/is) {     # only deal with refreshes of 99 secs or less
	     if ($tag =~ /url=(.*?)\"/is) {            # don't refresh if no url given
		 $newurl = $1;
#		 unless ($file =~ /$newurl$/) {         # don't refresh to same page
		 unless (($file =~ /$newurl$/) || ($newurl =~ /$path$file$/)) {         # don't refresh to same page
		     redir();
		     next LOOP;
		 }
	     }
	 }
     }
     
     # if we got here we must have got something and can end the loop
     
     $loop_flag = 1;
     
 }

# lose HTTP OK line
if ($code =~ /200|401/) {
    $contents =~ s/^HTTP[^\n]*\n//s;
}

# ignore all files not reported as some kind of text in content-type
if ($contents !~ /Content-Type:\s+text/is) {
    # send contents on unchanged
    print $contents;
    exit 0;
}

# pass cookies on but rewrite path
while ($contents =~ s/(Set-Cookie:[^\n]*\n)//isg) {
    my $c = $1;
    if ($c =~ /path=/) {
	# arbitrarily rewrite path to '/' so both betsie and originator can see it
	$c =~ s/(path=\/)[^;]*;/$1;/is;
    } else {
	$c =~ s/\n$/ path=\/;\n/;
    }
    print $c;
}

# get header out of contents
# finding it hard to match \n\n for some reason
$contents =~ s/^(.*?\n\s*\n)//s;
$header = $1;
$header =~ s/Content-Length.*\n//i; # because the length is now wrong

# add content type to header if not present
if ($header !~ /Content-Type/s) {
    $header =~ s/\n\n$/\nContent-Type: text\/html\n\n/s;
}

# handle WWW-Authenticate requests
if (($set_auth == 0) &&
    ($header =~ /WWW-Authenticate:([^\n]*\n)/isg)) {

#    ($basic_realm) = $header =~ /Basic realm=\"([^\"]*?)\"/is;

    $contents = make_auth_page();
    print $header, $contents;
    exit 0;

}

# *now* print header content type
print $header;

# set nocontenttype flag to ensure it never gets printed again
$nocontenttype = 0;

# make the body tag
$body = make_body();

# if we're on the settings page, send that and exit
if ($set != 0) {
    print <<HTML;	
<html>
<head>
<title>Betsie Settings Page</title>
<meta name="ROBOTS" content="NOINDEX, NOFOLLOW">
</head>
$body
</body>
</html>
HTML
					
    exit;
}

# we're not on the settings page. call parser routines
$contents = preparse($contents);

@x = split /\n/, $contents;

$contents = "";

# start sending
$script_flag = 0; # it will be 1 if we are in <SCRIPT> tags
$ws_flag = 0;   # it will be 2 if we just printed a second <BR> in a row

for (@x) {
    $contents = parse($_);
    unless ((!$contents) ||
	    ($script_flag == 1) ||
	    ($contents =~ /^\s+$/s) ||
	    (($ws_flag > 1) && ($contents =~ /^(\s*<br[^>]*?>\s*)+$/is))) {
        print $contents;
        if ($contents !~ /<br[^>]*?>\s*$/is) { $ws_flag = 0; }
        unless ($contents =~ /\n$/) { print "\n"; }
    }
    if ($contents =~ /<br[^>]*?>\s*$/is) { $ws_flag++; }
}

exit 0;

# subroutines

# base64encode
# give it a string
# get a base64 encoded version back
# Modified from code from MIME:Base64 module by Gisle Aas
sub base64encode {

    my $in = shift;
    my $res = "";

    $res = join '', map( pack('u',$_)=~ /^.(\S*)/, ($in=~/(.{1,45})/gs));

    $res =~ tr|` -_|AA-Za-z0-9+/|;               # `# help emacs
    # fix padding at the end
    my $padding = (3 - length($in) % 3) % 3;
    $res =~ s/.{$padding}$/'=' x $padding/e if $padding;
    return $res;

}

# urldecode
# urldecode a string
# Code from CGI.pm by Lincoln Stein
sub urldecode {

    my $str = shift;

    return "" unless $str;

    $str =~ tr/+/ /;       # pluses become spaces
    $str =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
    return $str;

}

# parse_parms
# give it a query string
# get a hash of parameters
# any url decoding will be done
sub parse_parms {

    my $qs = shift;
    my %parms;
    my $key;
    my $val;


    for (split '&', $qs) {
	($key, $val) = $_ =~ /^([^=]+?)=(.*)$/;
	if ($val =~ /\%/) { $val = urldecode($val); }
	$parms{$key} = $val;
    }

    return %parms;

}

# make_auth_cookie_and_loc
# give it an auth_page query string
# it returns the cookie we want to set
# and the location to redirect to
sub make_auth_cookie_and_loc {

    my $file = shift;
    my $str;
    my %pa;

    %pa  = parse_parms($postdata);

    $str = base64encode($pa{'betsie-u'}.":".$pa{'betsie-p'});

    return ($str, $pa{'betsie-pi'});

}

# make_auth_page
# returns a suitable authorisation page
sub make_auth_page {

    my $page;

    $body = make_body();

    $page = <<HTML;
<html>
<head>
<title>Authorisation Required</title>
</head>
$body
<h1>Betsie Authorisation Request Page</h1>

<p>You are trying to view a page which is password protected.
If you don't have a password for this page, please select the
browser's 'back' button to go back.

<p>$basic_realm

<form action="$pathtoparser" method="POST">

<input type="hidden" name="betsie-pi" value="$root$path$file">

<h2>User name</h2>
<input type="text" name="betsie-u">

<h2>Password</h2>
<input type="password" name="betsie-p">

<p><input type="submit" name="Submit">
<p><input type="reset" name="Reset">

</form>

</body>
</html>

HTML

    return $page;

}

# redir
# handles redirects.
# assumes $newurl contains the new url to redirect to...

sub redir {
    
    # case 1 - it begins with /
    
    if ($newurl =~ /^\//) {
	$newurl = "\/" . $root . $newurl;
	($root, $path, $file) = urlcalc($newurl);
	return;
    }
    
    # case 2 - it's the full path
    
    if ($newurl =~ /^http/) {
	$newurl =~ s/^http:\///;
	($root, $path, $file) = urlcalc($newurl);
	return;
    }
    
    # case 3 - it's a filename
    
    if ($newurl =~ /^(\w|-|_)+\.\w+$/) {
	$file = $newurl;
	return;
    }
    
    # case 4 - it's a relative path
    
    if ($newurl =~ /[(\w|-|_)+\/]*(\w|-|_)+\.\w+/) {
	$path .= $newurl;
	$path =~ s/\/((\w|-|_)+\.\w+)$/\//;
	$file = $1;
	$path =~ s#\/(\w|-|_)+\/\.\.##g;
	return;
    }
    
    # case 5 - the ones i haven't thought of...
    
    $x[0] = "Unknown redirect - $newurl";
    
    error();
    exit;
    
}

# error
# displays error page with message

sub error {

    my $error = shift || "";
    if($error ne "") {
	$x[0]=$error;
    }

    $root = "" unless $root;
    $path = "" unless $path;
    $file = "" unless $file;
    $contents = "" unless $contents;
    $body = "<body>" unless $body;

    # print contenttype if we haven't already
    if ($nocontenttype == 1) {
	print "Content-Type: text/html\n\n";
    }

    # Beat cross-site scripting vulnerability
    # All data from outside must have all tags removed
    ($root, $path, $file, $contents, $inpath, $x[0]) =
      map { s/<.*?>//gs; $_; } ($root, $path, $file, $contents, $inpath, $x[0]);


print <<HTMLERR;
<html>
<head>
<title>Betsie Error Page</title>
</head>
$body
<h1>Betsie Error Page</h1>
<p>Sorry, but Betsie was unable to find the page at http://$root$path$file.

<p>The error was as follows: $x[0].

<p>If you have just found a bug in Betsie (it's possible), please email the details
to <a href=\"mailto:$parsecontact\">$parsecontact</a>

<p><a href=\"$parsehome\">Return to the Betsie
homepage</a>, or select your browser's 'back' button (or equivalent) to return to the
page you just came from.

<p>Inpath: $inpath
<p>Root: $root
<p>Path: $path
<p>File: $file

</font>
</body>
</html>

HTMLERR

}


# graburl
# homebrewed page grabber thing. gets remote page.
sub graburl {

    my ($host, $file) = @_;
    
    my ($remote,                        # the name of the server
	$port,                          # the port
	$iaddr, $paddr, $proto, $line); # these vars used internally
    
    #DMY + WM
    if ($host eq $localhost) {
	$host = "localhost";
    }
    
    $remote  = $host;
    $port    = 80;

    # support non standard port numbers
    if ($remote =~ s/:(\d+)$//) { $port = $1; }
    
    unless ($iaddr   = inet_aton($remote)) {
	warn "no host: $remote";
	error("Error: no host", "$!");
    }
    
    $paddr   = sockaddr_in($port, $iaddr);
    $proto   = getprotobyname('tcp');
    select(SOCK);
    $| = 1;
    
    unless (socket(SOCK, PF_INET, SOCK_STREAM, $proto)) {
	warn "socket: $!";
	error("Error: socket problem", "$!");
    }

    unless (connect(SOCK, $paddr)) {
	warn "connect: $!";
	error("Error: connection problem", "$!");
    }
    
    select(STDOUT);
    
    print SOCK "$method $file HTTP/1.0\n";
    print SOCK "Accept: */*\n";
    print SOCK "User-Agent: $agent\n";
    print SOCK "Host: $host\n";
    if ($cookies) {
	print SOCK "Cookie: $cookies\n";
    }

    # support arbitrary extra headers
    if($extraheaders) {
	print SOCK $extraheaders;
    }


    if ($length > -1) { print SOCK "Content-Length: $length\n"; }
    print SOCK "\n";
    if ($length > -1) {
	print SOCK "$postdata\n";
    }

    
    @x = <SOCK>;
    
    unless (close (SOCK)) {
	warn "close: $!";
	return ("Error: problem closing socket", "$!");
    }
    
    $method = "GET";
    $length = -1;
    $postdata = "";
    
    return @x;
    
}

# parser routines

# preparse
# preparses take the whole page and does the bits that need the whole of the page

sub preparse {

    my $page = shift;
    
    # preparsing:
    
    # remove http header lines and insert missing html/body tags
    
    if ($page !~ /<html[^>]*>/is) {
	$page =~ s/^(.+?)\n\n/<html>/s;
    } else {
	$page =~ s/.*?<html([^>]*)>/<html$1>/is;
    }
    
    if ($page !~ /<\/html>/is) {
	$page .= "<\/html>";
    }
    
    if ($page !~ /<frameset/is) {    # don't do this to frames pages
	
	if ($page !~ /<\/body>/is) {
	    $page =~ s/<\/html>/<\/body>\n<\/html>/is;
	}
	
	if ($page !~ /<body/is) { # if there's no body tag
	    if ($page =~ /<\/head>/is) {	# look for an end head tag
		$page =~ s/<\/head>/<\/head>\n<body>/is;   # put body tag there if we find it
	    } else {
		if ($page =~ /<\/title>/is) {	# if we don't find end head look for end title
		    $page =~ s/<\/title>/<\/title><\/head>\n<body>/is;	# insert both end head and body start
		} else {
		    $page =~ s/<html([^>]*)>/<html$1><head><title>$root$path$file<\/title><\/head><body>/is;
		    # this is clumsy, true, but so is the code it's trying to fix.
		}
	    }
	}
	
    }
    
    # now we have a head we can look out for and exclude robots.
    $page =~ s/(<\/head>)/<meta name="ROBOTS" content="NOINDEX, NOFOLLOW">\n$1/is;
    
    # remove stylesheets part 1
    $page =~ s/<style.+?<\/style>//gis;
    
    # remove java
    $page =~ s/<applet.+?<\/applet>/<p>Java applet removed\.\n/gis;
    
    # put MAPs in body (later on AREAs become As...)
    while ($page =~ s/<map[^>]*?>(.*?)<\/map>(.*)(<\/body>)/$2\n$1\n$3/is) {};
        
    # remove all extraneous whitespace and newlines in tags
    $page =~ s/\s+=/=/gs;
    $page =~ s/=\s+/=/gs;
    $page =~ s/<\s+([^>]+)>/<$1>/gs;
    $page =~ s/<([^>]+)\s+>/<$1>/gs;
    while ($page =~ s/<([^>\n]+?)\n([^>]*)>/<$1 $2>/gs) {}
    while ($page =~ s/<([^>]+?)\s{2,}([^>]+)>/<$1 $2>/gs) {}
    
    # remove empty links - mucho ta to Matt Blakemore for suggesting this one
    $page =~ s/<a[^>]*href\s*\=\s*[^>]*>\s*<img[^>]*alt\s*\=\s*\"\"[^>]*>\s*<\/a>//gis;

    # go to move_nav and move the nav
    $page = move_nav($page);  

    # go to move_extra and do any other fiddling
    $page = move_extra($page);
    
    # remove hidden javascript. and comments. (sorry).
    $page =~ s/<!--.*?-->//gs;
    
    # make sure no two tags are on same line
    $page =~ s/(>)([^\n|=])/$1\n$2/gs;
    
    # remove blank lines
    $page =~ s/\s{2,}/\n/gs;

    # find and fix text-only links
    $page =~ s/<a\s+href\s*=\s*\"$selfnuke[^\"]*\"[^>]*>.*?<\/a>//sig;

    return $page;
}

# move_extra
# moves arbitrary other blocks of code around the page
# block n is delimited by the following
# <!-- BETSIEBLOCK n -->
# ... code
# <!-- ENDBETSIEBLOCK n -->
# blocks end up in the order they were numbered
# at the bottom of the page
sub move_extra {

    my $page = shift;

    my $start = "(?:BETSIEBLOCK)";
    my $end = "(?:ENDBETSIEBLOCK)";

    my $count = 1;

    while ($page =~ /<!--\s+$start/is) {
	# move the nth betsie block
	$page =~ s/(.*?)<!--\s+$start\s+$count[^>]+?-->(.*?)<!--\s+$end\s+$count[^>]+?-->(.*)<\/body>/$1$3$2<\/body>/is;
	$count++;
    }

    return $page;

}

# move_nav
# moves the nav bar around
# this one is for the BBC site. your site may need a whole different one...

sub move_nav {

    my $page = shift;
    
    my $start_nav = '(?:GLOBAL\s+NAVIGATION|GLOBALNAVBEGIN)';
    my $end_nav = '(?:End\s+of\s+GLOBAL\s+NAVIGATION|SERVICESNAVEND)';

    if ($root =~ /\.bbc\.co\.uk$/) {
	
	# first make sure all table widths have double quotes
	
	$page =~ s/(<t[^>]*?)width=(\d+)/$1width="$2"/gis;
	
	for ($root) {
	    
	    /^news/ and do {
		
		# news nav mangling - sits in a table width 90 pixels... Or 100 pixels. Depends on the template.
		
		$page =~ s/(.*?)<table([^>]*?)width=[\"|\']?(?:90|100)[\"|\']?.*?>(.*?)<\/table>(.*)<\/body>/$1$4$3<\/body>/is;

		last;
		
	    };
	    
	    /^www/  and do {
		
		# normal or worldservice...
		
		if ($path =~ /worldservice|arabic|cantonese|mandarin|russian|spanish|ukrainian/) {
		    
		    # world service nav mangling - sits in a td width 98 pixels and followed by td width 1 pixel
		    # but mileage varies, hence all the \d's...
		    
		    $page =~ s/(.*?)<td([^>]*?)width=[\"|\'](?:9\d|1\d\d)[\"|\'].*?>(.*?)<td([^>]*?)width=[\"|\']\d[\"|\'].*?>(.*)<\/body>/$1$5$3<\/body>/is;

		} elsif ($path =~ /^\/news\//) {

		    # news nav mangling - sits in a table width 90 pixels... Or 100 pixels. Depends on the template.

		    $page =~ s/(.*?)<table([^>]*?)width=[\"|\'](?:90|100)[\"|\'].*?>(.*?)<\/table>(.*)<\/body>/$1$4$3<\/body>/is;
		    
		} else {
		    
                    # deal with old education navbar
		    
                    last if ($page =~ s/(<a href=\"\/education\/nav\/bbcedbar\.map\">).*?(<\/a>)/$1BBC Education$2/is);
                      
		    if ($page =~ /<!--\s+$start_nav/is) {

                      	# code for commented stuff here
                      	$page =~ s/(.*?)<!--\s+$start_nav[^>]+?-->(.*?)<!--\s+$end_nav[^>]+?-->(.*)<\/body>/$1$3$2<\/body>/is;
 
                    } else {
                      
                      	# Old standard navs. Should be 107 and 3 pixels, but you never know...
                    	$page =~ s/(.*?)<td([^>]*?)width=[\"|\']1\d\d[\"|\'].*?>(.*?)<td([^>]*?)width=[\"|\']\d[\"|\'].*?>(.*)<\/body>/$1$5$3<\/body>/is;

		    }
						    
		}

		last;

	    };
 
	    # i don't know where we are, here, but lets try for standard nav bars anyway...
	    if ($page =~ /<!--\s+$start_nav/is) {
		# code for commented stuff here>
           	$page =~ s/(.*?)<!--\s+$start_nav[^>]+?-->(.*?)<!--\s+$end_nav[^>]+?-->(.*)<\/body>/$1$3$2<\/body>/is;
	    } else {

		# if in doubt, do nothing, to avoid sending back empty documents.

	    }
	}
    }
    
    
    return $page;	
	
}

# parse
# handles the line-by-line bits of betsification
sub parse {
    
    my ($line) = shift;
    my $link;
    my $alt;    # used in area tag handler
    my $target; # ditto
    
    $line =~ s/click here/select this link/gis;
    
    # nuke javascript event handlers
    while ($line =~ s/(<[^>]*?)(\s+on\S+?\s*=\s*\".*?\")+(.*?>)/$1 $3/i) {}; # dbl quotes
    while ($line =~ s/(<[^>]*?)(\s+on\S+?\s*=\s*\'.*?\')+(.*?>)/$1 $3/i) {}; # sgl quotes
    while ($line =~ s/(<[^>]*?)(\s+on\S+?\s*=\s*\S+?)(>)/$1 $3/i) {};     # no quotes. naughty!
    
    # lose inline stylesheeting
    $line =~ s/(<[^>]*?)style\s*=\s*\".*?\"/$1/gis;
    
    # lose arbitrary justification arbitrarily
    $line =~ s/(<[^>]*?)align\s*=\s*\".*?\"/$1/gis;
    
    # S T O P   P E O P L E   L I K E   T H I S (thanx to T.V.Raman for the suggestion)
    if ($line =~ /(\w ){5,}/) {
    	$line =~ s/(\w) /$1/g;
    }
    
    my $tag;
    $line =~ /<(\S+)[^>]*?>/;
    $tag = $1 || "";
    if ($tag eq "") { return $line; }
    $tag = lc $tag;
    
    for ($tag) {
	
	# handle javascript script
	/noscript/		 and do {
	    $line =~ s/<(?:\/)?noscript[^>]*?>//gis;	 
	    last;
	};
	
	/script/ and do {
	    if ($line =~ /<script/i) {
		$script_flag = 1;
		$line =~ s/<script.*$//gis;
	    } elsif ($line =~ /<\/script/i) {
		$line =~ s/^.*?<\/script>//i;
		$script_flag = 0;
	    }
	    last;
	};
	
	# lose nobr
	/nobr/   and do {
	    $line =~ s/<(?:\/)?nobr>//gis;
	    last;
	};
	
	# lose link rel=stylesheet *only*
	/link/   and do {
	    if ($line =~ /rel\s*=\s*\"?stylesheet\"?/gis) {
		$line =~ s/<link[^>]*?>//gis;
	    }
	    last;
	};
	
	# lose center tag
	/center/		 and do {
	    $line =~ s/<(?:\/)?center[^>]*?>//gis;	 
	    last;
	};
	
	
	# nuke all fonts
	/font/	 and do {
	    $line =~ s/<(?:\/)?font[^>]*?>//gis;
	    $line =~ s/<(?:\/)?basefont[^>]*?>//gis;
	    last;
	};
	
	/base/	 and do {
	    
	    if (($link) = $line =~ /<base[^>]+?href\s*=\s*(\S+)[^>]*?>/i) {
		$link =~ s/\"//g;
		$link =~ s#^http:\/##i;
		($root, $path) = urlcalc($link);
	    }
	    
	    last;
	};
	
	# lose layers
	/layer/	and do {
	    $line =~ s/<(?:\/)?layer[^>]*?>//gis;
	    last;
	};
	
	# lose divs
	/div/	and do {
	    $line =~ s/<(?:\/)?div[^>]*?>//gis;
	    last;
	};

	# detableiser
	/table/	and do {
	    $line =~ s/<(?:\/)?table[^>]*?>//gis;
	    last;
	};
	/tr$/		 and do {
	    $line =~ s/<(?:\/)?tr[^>]*?>//gis;	 
	    last;
	};
	# this is very rudimentary and could be improved
	# but not till i'm sure what the right way is
	/th$/ and do {
	    $line =~ s/<\/th>//gis;
	    $line =~ s/<th.*?>/<br>/gis;
	    last;
	};
	/td$/		 and do {
	    $line =~ s/<\/td>//gis;
	    $line =~ s/<td.*?>/<br>/gis;
	    last;
	};
	
	# link masher
	/^a$/		 and do {
	    
	    # get the link out and remove any quoting
	    $line =~ /<a[^>]+?href\s*=\s*(\S+)[^>]*?>/i;
	    $link = $1 || "";
	    $link =~ s/\"//g;
	    $link =~ s/\'//g;
	    last if ($link =~ /^\#/);	 # ignore anchors
	    
	    $line =~ s/\s*=\s*/=/;
	    
	    # check for URL passing scripts and make them external
	    # this should fix webguide and all other script based
	    # URL passers for whom a href is just too easy... :)

	    # note that URLs automatically end if an & is present.
	    # note that this is a hack to get around an old bbc-specific
	    # problem, and should probably now be removed, since it surely
	    # breaks interoperability with other scripts.
	    
	    if ($link =~ m#\?.*?http(:|CHR\(58\))\/\/#i) {
		
		$link =~ s/CHR\(58\)/:/gi;
		$link =~ s/.*?(\?.*)/$1/;
		$link =~ s#^\?.*?(http:\/\/.*)$#$1#i;
		$link =~ s/&.*$//;
		unless (safe($link)) {
		    $line =~ s#(<a[^>]+?href=)\S+([^>]*?>)#$1$link$2 (External)#i;
		    last;
		}
	    }
	    
	    # handle real audio
	    
	    if ($link =~ /\.(ram|rm|ra)$/i) {
		if ($link =~ /^http:/i) {
		    last;
		}
		if ($link =~ /^\//) {
		    $link = "http:\/\/" . $root . $link;
		    $line =~ s/(<a[^>]+?href=)\S+([^>]*?>)/$1"$link"$2/i;
		    last;
		}
		$link = $root . $path . $link;
		$link =~ s#\/\w+\/\.\.\/#\/#g;
		$link = "http:\/\/" . $link;
		$line =~ s/(<a[^>]+?href=)\S+([^>]*?>)/$1"$link"$2/i;
		last;
	    }
	    
	    # handle fully qualified links
	    
	    if ($link =~ /^\w+:/) {
		unless (safe($link)) {
		    $line =~ s/(<a[^>]+>)/$1 (External)/i;
		    last;
		}
		if ($link =~ /^http/i) {
		    $link =~ s/^http:\/(\/.*)$/$pathtoparser$setstr$1/i;
		    $line =~ s/(<a[^>]+?href=)\S+([^>]*?>)/$1"$link"$2/i;
		} elsif ($link =~ /javascript:/) {
		    $line =~ s/<a[^>]+>/<a href="">/i;
		}
		last;
	    }
	    
	    # now the slash led links
	    
	    if ($link =~ /^\//) {
		$link = $pathtoparser . "$setstr" ."\/". $root . $link;
		$line =~ s/(<a[^>]+?href=)\S+([^>]*?>)/$1"$link"$2/i;
		last;
	    }
	    
	    # now the rest of them
	    
	    $link = "\/" . $root . $path . $link;
	    $link =~ s#\/\w+\/\.\.\/#\/#g;
	    $link = $pathtoparser. "$setstr" . $link;
	    $line =~ s/(<a[^>]+?href=)\S+([^>]*?>)/$1"$link"$2/i;
	    last;
	};
	
	/^area$/			and do {
	    
	    # get the link out and remove any quoting
	    ($link) = $line =~ /<area[^>]+?href\s*=\s*(\S+)[^>]*?>/i;
	    $link =~ s/\"//g;
	    $link =~ s/\'//g;
	    last if ($link =~ /^\#/);	 # ignore anchors
	    
	    # get alt out
	    
	    ($alt) = $line =~ /<area[^>]+?alt\s*=\s*\"(.*?)\"[^>]*?>/i;
	    
	    $alt = $alt || $link;  # so non-alt tagged stuff sort of works...
	    
	    # get target out (if present) - we don't need to do this elsewhere
	    # because it's retained, but here we're rewriting the whole tag...
	    
	    ($target) = $line =~ /<area[^>]+?target\s*=\s*\"(.*?)\"[^>]*?>/i;
	    
	    $target = $target || "_top";  # so non-targeted stuff sort of works...
	    
	    # handle fully qualified links
	    
	    if ($link =~ /^\w+:/) {
		unless (safe($link)) {
		    $line = "<a href=\"$link\" target=\"$target\">$alt (External)</a>&nbsp;";
		    last;
		}
		if ($link =~ /^http/i) {
		    $link =~ s/^http:\/(\/.*)$/$pathtoparser$setstr$1/i;
		    $line = "<a href=\"$link\" target=\"$target\">$alt</a>&nbsp;"
		    } elsif ($link =~ /javascript:/) {
			$line = "<a href=\"\">&nbsp;";
		    }
		last;
	    }
	    
	    # now the slash led links
	    
	    if ($link =~ /^\//) {
		$link = $pathtoparser . "$setstr" ."\/". $root . $link;
		$line = "<a href=\"$link\" target=\"$target\">$alt</a>&nbsp;";
		last;
	    }
	    
	    # now the rest of them
	    
	    $link = "\/" . $root . $path . $link;
	    $link =~ s#\/\w+\/\.\.\/#\/#g;
	    $link = $pathtoparser. "$setstr" . $link;
	    $line = "<a href=\"$link\" target=\"$target\">$alt</a>&nbsp;";
	    last;
	    
	};
	
	
	/^frameset$/	and do {
	    $line =~ s/(<frameset[^>]*?) cols/$1 rows/i;
	    $line =~ s/(<frameset[^>]+)frameborder\s*=\s*[\'|\"]?[no|0][\'|\"]?([^>]*)>/$1 $2>/i;
	    $line =~ s/(<frameset[^>]+)border\s*=\s*[\'|\"]?0[\'|\"]?([^>]*)>/$1 $2>/i;
	    while ($line =~ s/(<frameset[^>]*?\=\s*[\"|\']?\s*)\d{1,2}\%?(,?)/$1\*$2/i) {};
	    last;
	};																	 
	
	/^frame$/		 and do {
	    
	    # make all frames resizeable...
	    
	    $line =~ s/(<frame[^>]+?)noresize[="noresize"]?([^>]*>)/$1 $2/ig;
	    $line =~ s/(<frame[^>]+)frameborder\s*=\s*[\'|\"]?[no|0][\'|\"]?([^>]*)>/$1 $2>/i;
	    $line =~ s/(<frame[^>]+)border\s*=\s*[\'|\"]?0[\'|\"]?([^>]*)>/$1 $2>/i;
	    
	    # get the link out and remove any quoting
	    
	    ($link) = $line =~ /<frame[^>]+?src\s*=\s*(\S+)[^>]*?>/i;
	    last if ($link eq "");
	    $link =~ s/\"//g;
	    $link =~ s/\'//g;
	    $line =~ s/\s*=\s*/=/;
	    if ($line !~ /scrolling/i) {
		
		$line =~ s/(<frame[^>]+)>/$1 scrolling=yes>/i;
		
	    } else {
		
		$line =~ s/(<frame[^>]+)scrolling\s*=\s*[\'|\"]?no[\'|\"]?([^>]*)>/$1 scrolling=\"yes\" $2>/i;
		
	    }
	    # handle fully qualified links
	    
	    if ($link =~ /^\w+:/) {
		if ($link =~ /^http/i) {
		    $link =~ s/^http:\/(\/.*)$/$pathtoparser$setstr$1/i;
		    $line =~ s/(<frame[^>]+?src=)\S+([^>]*?>)/$1"$link"$2/i;
		}
		last;
	    }
	    
	    # now the slash led links
	    
	    if ($link =~ /^\//) {
		$link = $pathtoparser . "$setstr" ."\/". $root . $link;
		$line =~ s/(<frame[^>]+?src=)\S+([^>]*?>)/$1"$link"$2/i;
		last;
	    }
	    
	    # now the rest of them
	    
	    $link = "\/" . $root . $path . $link;
	    $link =~ s#\/\w+\/\.\.\/#\/#g;
	    $link = $pathtoparser . "$setstr". $link;
	    $line =~ s/(<frame[^>]+?src=)\S+([^>]*?>)/$1"$link"$2/i;
	    last;
	};
	
	/^form$/		 and do {
	    
	    # get the link out and remove any quoting
	    
	    ($link) = $line =~ /<form[^>]+?action\s*=\s*(\S+)[^>]*?>/i;
	    last if ($link eq "");
	    $link =~ s/\"//g;
	    $link =~ s/\'//g;
	    $line =~ s/\s*=\s*/=/;
	    
	    # handle fully qualified links
	    
	    if ($link =~ /^\w+:/) {
		if ($link =~ /^http/i) {
		    $link =~ s/^http:\/(\/.*)$/$pathtoparser$setstr$1/i;
		    $line =~ s/(<form[^>]+?action=)\S+([^>]*?>)/$1"$link"$2/i;
		}
		last;
	    }
	    
	    # now the slash led links
	    
	    if ($link =~ /^\//) {
		$link = $pathtoparser .$setstr. "\/".$root . $link;
		$line =~ s/(<form[^>]+?action=)\S+([^>]*?>)/$1"$link"$2/i;
		last;
	    }
	    
	    # now the rest of them
	    
	    $link = "\/" . $root . $path . $link;
	    $link =~ s#\/\w+\/\.\.\/#\/#g;
	    $link = $pathtoparser .$setstr. $link;
	    $line =~ s/(<form[^>]+?action=)\S+([^>]*?>)/$1"$link"$2/i;
	    last;
	};
	
	/img/		 and do {
	    
	    # case 1 - image has empty alt tag
	    
	    $line =~ s/<img[^>]*?alt="".*?>//i;
	    
	    # case 2 - image has non-empty alt tag
	    
	    $line =~ s/<img[^>]*?alt="(.+?)".*?>/<p>$1/i;
	    
	    # case 3 - image has no alt tag at all
	    
	    $line =~ s/<img.*?>//i;
	    
	    last;
	    
	};
	
	/input/		 and do {
	    
	    # only screw with it if it's an image...
	    
	    if ($line =~ /(<input[^>]*?type=(\"|\')?)image/gis) {
		$line =~ s/($1)image/$1submit/gis;
		last;
	    }
	    
	    last;
	    
	};
	
	/embed/	 and do {
	    
	    # sort shockwave etc plus anything else embedded with src
	    
	    # currently attempts to make sure all src left after losing images has the right path
	    
	    $line =~ s/<([^>]+?)src=([\'|\"]?)(\/\S+?)([\'|\"]?)([^>]*?)>/<$1SRQ=$2http:\/\/$root$3$4$5>/i;
	    $line =~ s/<([^>]+?)src=([\'|\"]?)(http:\/\/\S+?)([\'|\"]?)([^>]*?)>/<$1SRQ=$2$3$4$5>/i;
	    $line =~ s/<([^>]+?)src=([\'|\"]?)(\S+?)([\'|\"]?)([^>]*?)>/<$1src=$2http:\/\/$root$path$3$4$5>/i;
	    $line =~ s#\/\w+\/\.\.\/#\/#g;
	    $line =~ s/<([^>]+?)SRQ/<$1src/i;
	    
	};
	
	/body/		and do {
	    
	    if ($line =~ /<body/i ) {
		$line =~ s/<body[^>]*?>/$body/i;
		last;
	    }
	    
	    $line =~ s#<\/body>#\n<p><a href=\"$pathtoparser$chsetstr/$root$path$file\">Change Text Only Settings<\/a>\n<p><a href=\"http:\/\/$root$path$file\">Graphic version of this page<\/a>\n<\/font>\n<!-- This page parsed by Betsie version $version-->\n<\/body>#is;
	    
	};
	
    }
    
    return $line;
    
}

# url calc takes an inpath (is full url without http:/ at beginning
# ie it expects it to begin with a slash and then have the domain name,
# and then whatever else we have or have not got...
sub urlcalc {

    my $url = shift;
    my $root = "";
    my $path = "";
    my $file = "";
    
    $url =~ s#^\/([^\/]*)##;
    $root = $1;
    ($path, $file) = $url =~ /(.*\/)(.*?)$/;
    if ($path eq "") { $path = "\/"; }
    if ($file eq "/") { $file = ""; }
    
    return $root, $path, $file;
    
}

# alarm
# kills hanging Betsies. added by Damion Yates From BBC R&D (Kingswood)
# doesn't work on machines that don't implement alarm
sub alarm {
    my $signame = shift;

    select(STDOUT); # in case we're timing out on a socket...

    warn "Betsie Alert: Timeout after $alarm seconds SIG$signame received\n";

    error("Attempt to load this page timed out. Please try again later.");

    exit 1;
}

# safe
# makes sure the url given is in the safe list

sub safe {
    
    my $url = shift;
    
    return 1 if ($url =~ /^(javascript|mailto):/is);
    
    for (@safe) {
	return 1 if ($url =~ /\w+:\/\/((\w|-)+\.)*$_/is);
    }
    return 0;
    
}

# make_body
# returns a suitable body tag
# including settings page if appropriate
sub make_body {
    
    my $b = "";
    my ($slash, $set, $code, $font, $font_size) = split '', $setstr;
    
    # brief sanity check - font size must be 1 to 7, code 0 to 3, font 0 to 9 (hence no check)
    # we don't really care about set or slash. in fact we don't even use slash.
    if ($font_size > 7 || $font_size == 0) { $font_size = 5; }
    if ($code > 3) { $code = 0; }
    
    if ($set == 1) {
	
	$b = "<h1>Text Only Settings Page:</h1>
<p>You can change the text-only settings by selecting from the following links. Select the last link when you are done.
<p>Alternatively, <a href=\"$pathtoparser/1005/$root$path$file\">select this link</a> to return to the default settings.
<h2>Colours:</h2>
<p><a href=\"$pathtoparser/10$font$font_size/$root$path$file\">Yellow On Black</a>
, <a href=\"$pathtoparser/11$font$font_size/$root$path$file\">Black On White</a>
, <a href=\"$pathtoparser/12$font$font_size/$root$path$file\">White On Blue</a>
, <a href=\"$pathtoparser/13$font$font_size/$root$path$file\">Black On Cream</a>	
<h2>Font Size:</h2>
<p><a href=\"$pathtoparser/1".$code.$font."1/$root$path$file\">Tiny</a>
, <a href=\"$pathtoparser/1".$code.$font."2/$root$path$file\">Small</a>
, <a href=\"$pathtoparser/1".$code.$font."3/$root$path$file\">Medium Small</a>
, <a href=\"$pathtoparser/1".$code.$font."4/$root$path$file\">Medium</a>
, <a href=\"$pathtoparser/1".$code.$font."5/$root$path$file\">Large</a>
, <a href=\"$pathtoparser/1".$code.$font."6/$root$path$file\">Extra Large</a>
, <a href=\"$pathtoparser/1".$code.$font."7/$root$path$file\">Extra Extra Large</a>
<h2>Font:</h2>
<p><a href=\"$pathtoparser/1".$code."0$font_size/$root$path$file\">Verdana</a>
, <a href=\"$pathtoparser/1".$code."1$font_size/$root$path$file\">Times</a>
, <a href=\"$pathtoparser/1".$code."2$font_size/$root$path$file\">Courier</a>
, <a href=\"$pathtoparser/1".$code."3$font_size/$root$path$file\">Helvetica</a>
, <a href=\"$pathtoparser/1".$code."4$font_size/$root$path$file\">Arial</a>
, <a href=\"$pathtoparser/1".$code."5$font_size/$root$path$file\">Bookman Old Style</a>
, <a href=\"$pathtoparser/1".$code."6$font_size/$root$path$file\">Geneva</a>
, <a href=\"$pathtoparser/1".$code."7$font_size/$root$path$file\">Chicago</a>
, <a href=\"$pathtoparser/1".$code."8$font_size/$root$path$file\">Courier New</a>
, <a href=\"$pathtoparser/1".$code."9$font_size/$root$path$file\">System</a>
<h2>Notes:</h2>
<p>Not all browsers support all possible font, size and colour combinations.
<p>Most browsers allow you to specify your own font, size and colour combinations, overriding any given 
by the current page. You may find that route more flexible than the options allowed here. Consult your browser
documentation for details.
<hr>
<p><b><a href=\"$pathtoparser/0$code$font$font_size/$root$path$file\">Select this link when done</a></b>";

    }
	
    $b = "<body bgcolor=\"$bg[$code]\" text=\"$text[$code]\" link=\"$link[$code]\" alink=\"$alink[$code]\" vlink=\"$vlink[$code]\">\n<font face=\"$font_face[$font]\" size=\"$font_size\">\n" . $b;
	
    return $b;
    
}


__END__


=head1 NAME

Betsie - the BBC Education Text To Speech Internet Enhancer

=head1 DESCRIPTION

Betsie is a simple CGI filter to improve the accessibility of arbitrary valid HTML pages.

=head1 README

Betsie is a simple CGI filter to improve the accessibility of arbitrary valid HTML pages. It
effectively creates an on-the-fly text-only version of your site.

For full details of how to use and install Betsie, please refer to the following URL:

http://www.bbc.co.uk/education/betsie/readme.txt

For full details of Betsie's current functionality, contact details, etc etc etc, 
visit the Betsie website: http://www.bbc.co.uk/education/betsie/

=head1 LICENCE

For full details of the licence arrangements for Betsie, please refer to the following URL:

http://www.bbc.co.uk/education/betsie/licence.txt

Executive summary - it's free if you want to use it but you can't sell it.

=head1 PREREQUISITES

This script requires the C<socket> module.

=head1 AUTHOR

Wayne Myers - wayne.myers@bbc.co.uk

=pod OSNAMES

any

=pod SCRIPT CATEGORIES

CGI/Filter
Web

=cut

















































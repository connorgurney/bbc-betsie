BETSIE - README
===============

Readme for version 1.5.*

- updated 23rd April, 2002
- more minor changes, 3rd May, 2001
- minor changes, 26th April, 2001
- another update, 19th April, 2001
- updated again, 15/12/99
- updated, 13/12/99
- some minor errors corrected, 25/2/99

LICENSING AND COPYRIGHT
-----------------------

The Betsie distribution consists of five files as follows:

parser.pl   - the Perl source code for the Betsie parser
README      - this file
LICENCE     - the terms under which Betsie is distributed
ChangeLog   - listing the changes made to the code
TODO        - a rough document outlining current wishlist items

Betsie is (c) 1998 - 2001 BBC Digital Media. See the file LICENCE for
full terms and conditions. Acceptance of the licence is implied by your
use of Betsie in any way shape or form - the licence basically boils
down to this: you can use Betsie in any way you like so long as you
don't sell it and you don't redistribute it without crediting the BBC as
specified. If you modify it or incorporate it into something else you
can't sell that either.

WHAT'S NEW 1.5.11
-----------------

Support for basic authentication added.
Support for multiple rearrangable blocks added.
Numerous bug-fixes.

WHAT HAPPENED TO VERSIONS 1.5.7 - 1.5.10?
-----------------------------------------

They didn't get released, due to pressures of other BBC-related work. :(

WHAT'S NEW 1.5.6
----------------

Sourceforge cvs and mailing list finally set up.
Configuration instructions for IIS/NT added to README.
Various tweaks to readme, including better move_nav section.
Various bugfixes to code, detailed below.


WHAT'S NEW IN 1.5
-----------------

Various minor bugs have been fixed, and extra code has now been added to allow
the user to change the font, font size and colour settings for the page. This
information is encoded in the URL, but old Betsie URLs will still work, so the
whole thing is backwards compatible with your existing code.

WHO BETSIE IS FOR
-----------------

Betsie is a server-side solution to the problem faced by a large number
of websites - they absolutely must be accessible to everybody, but for
whatever reason they are not, and there aren't the resources to go
through every page fixing them completely by hand.

Betsie can provide an on the fly text-only version of every page on your
site which can be (more or less) guaranteed to be accessible, and can be
modified to include features of code manipulation that are wholly
specific to your site. An example of this is the code used in the BBC's
online version of Betsie which handles the BBC navbar.

If you are a server administrator, or are involved in the design and
technical accessibility issues around your website, then Betsie is
likely to be at least interesting, if not useful to you. This document
contains a reasonably comprehensive set of instructions as to how to
install and set up Betsie on your own server. It assumes you have a
working knowledge of Perl and good knowledge of HTML.

If you are a home user or suffer from accessibility problems in general,
then I am afraid that unless you are also something of a technical
expert, Betsie is far more likely to be something you use than something
you install and set up. To use Betsie you need merely visit a site on
which it has already been installed. You can visit the Betsie
website ( http://www.bbc.co.uk/education/betsie/ ) for a list of places
where Betsie has been installed and where you can use it without having to
install or set up anything.

SETTING BETSIE UP
-----------------

Before You Begin
----------------

You need:

a) Some Perl. If you don't know any Perl, now would be a good time to
start learning. http://www.perl.com/ is a good place to start that.

b) Access to a web server. If you don't have anywhere to put Betsie, or
if you aren't allowed to install CGI scripts, now would be a good time
to start talking to your ISP or server administrator about somewhere to put it.

c) A reasonably consistent set of pages to work with and a reasonable
knowledge of HTML, including accessibility issues. If the URL
http://www.w3c.org/WAI/ means nothing to you, this would be a good time
to check it out.

What You Must Do
----------------

There are a few things you have to do and a few things you can choose
whether or not to do. As follows:

a) You have to...

Make sure that the following variables have appropriate values as
described below: 

  $pathtoparser - the url of the location of the parser file itself

  $parsehome    - the url of the homepage for your installation of
                  Betsie. If you wish, you may leave this set to
                  http://www.bbc.co.uk/education/betsie/
                  which is the central Betsie homepage at the BBC.

  $parsecontact - the email address of the person you wish to have
                  contacted with regard to any problems that may arise
                  with this installation of Betsie.

  $localhost    - must contain the name of the server you are going to
                  install Betsie on.

  @safe         - must contain the list of urls you are going to allow
                  this installation of Betsie to point at. If you aren't
                  going to be using this feature, it doesn't really
                  matter what you put in here.

  $maxpost      - contains the maximum amount of data that can be
                  submitted via Betsie using a POST request. The default
                  given is 65536 bytes, but you will want to double
                  check this with your sysadmin to make sure that it
                  corresponds to the default value used by the server.

b) You might well want to...

  Write some code to fix specific problems to your site.

  Move Nav Bars
  -------------

  For example, if you know that all your pages (or an appreciable,
  drillable-down-to subset of them thereof) are constructed in such a way
  that there is a nav bar that sits in a table which is 150 pixels wide on
  the left hand side of every page (sound familiar... no?) then all you
  need to do is come up with a way of finding it and putting it somewhere
  else.

  If you don't know why you might want to move a lefthand navbar to the
  bottom of the page, you should look at a number of such sites in Lynx or
  some other text only browser, and note what happens when you move from
  page to page in such a site... the lefthand navbar appears at the top of
  every page every time, and if there's a lot in it, you won't necessarily
  know whether or not you have successfully arrived at the page you want
  for an irritatingly long time.

  This (and other global changes) can be usefully inserted in the
  parser.pl file in the move_nav function. The move_nav function is called
  with preparse.

  In preparse, the whole of the HTML page is held in a string called $page
  and manipulations based on the whole of the page can therefore be done.

  Here's an example move_nav routine, which may be more useful to you
  than the rather BBC specific version in the current distribution of
  the code.

sub move_nav() {

    my $page = shift;
    
    my $start_nav = "(?:<!-- Nav Begin -->)";
    my $end_nav = "(?:<!-- Nav End -->)";

    $page =~ s/(.*?)$start_nav(.*?)$end_nav(.*)<\/body>/$1$3$2<\/body>/is;

    return $page;

}

  First, the whole page gets passed in.

  Next two variables, $start_nav and $end_nav are set, corresponding
  to the comments in the HTML code that are being searched for.

  Notice the use of the '?:' construct - this means that Perl will allow
  you to insert alternatives inside the brackets using '|', but will
  not count the contents of the brackets in the replacement part of
  the regular expression.

  The fourth line is the regexp that actually moves the nav bar.

  If you are unable to ensure that all your nav bars begin and end
  with a set of standard comments, you might want to try writing code
  specific to the HTML that you are looking for. However, be warned
  that this is much harder to maintain over time, since every time the
  HTML is changed, the code in Betsie must be changed.

  Safe List
  ---------
  You might also want to disable the safe list. You can do this in any one
  of several different ways, the easiest and simplest of which is to
  insert the line 'return 1;' at the beginning of the 'safe' subroutine.

  Once you have done this, Betsie will be able to point at any web site
  anywhere you like on the internet and will never describe sites as
  'external'.

  On the other hand, you might want to use the safe list. In which case,
  simply populate the @safe array with the urls you want to allow your
  installation of Betsie to point at.

3 - Finally, having made all the changes you want to make, check it all
still works and so forth in the normal way and move on to installing it.


INSTALLING BETSIE
-----------------

1 - I can't really help you with this, save to remind you of the
following:

  a - Did you change the #!/usr/local/bin/perl/ line to something
  appropriate to the location of Perl on your server?

  b - Did you ensure that all the permissions were set up correctly?

  c - Did you check that all the alterations you made to parser.pl left
  it syntactically intact?

If the answer to all of the above is yes, and it still isn't working,
then I'm afraid I have no idea what is going on either. Sorry.

2 - This isn't compulsory, but will be (hopefully) highly advantageous
for anyone using Betsie on their site and will also make me very
grateful, to wit and viz: email me, wayne.myers@bbc.co.uk to let me know
that you have installed Betsie, so I can make sure to keep you up to
date with any new versions, help you if possible with tweaks and
site-specific problems you may come across, and, possibly, add your site
to the list of accessible sites I am compiling for the Betsie web site
(forthcoming) itself.

3 - Using NT/IIS and find it doesn't work?

Microsoft's IIS server, out of the box, does not support the PATH_INFO
environment variable, which Betsie relies on, since it is disabled by
default. However, by following the instructions on the following page,
PATH_INFO can be re-enabled.

http://support.microsoft.com/support/kb/articles/Q184/3/20.ASP

In addition to giving instructions on enable PATH_INFO, this page also
claims that doing so is a security risk. In the case of Betsie, this
will not be true, since Betsie does not use PATH_TRANSLATED, and the
way in which Betsie uses PATH_INFO does not give away any information
about the server which may be used to mount an attack.

It is also necessary to comment out the alarm() call on NT, which does
not implement it.

For further details on AllowPathInfoForScriptMappings, see:

http://msdn.microsoft.com/library/psdk/iisref/apro8mr7.htm

4 - Whoops. Almost forgot. Now you have to fix your HTML. All of it.

Being an on-the-fly HTML repair tool, Betsie also may be used as a way
of identifying pages that require repair by hand. This is why this
readme recommends you install Betsie before fixing your HTML, since you
can then use Betsie to help you through that process.

See the Limitations section for further details of the kind of HTML that
may cause problems for Betsie. (It will be causing problems anyway.)

USING BETSIE
------------

Called without any PATH_INFO, Betsie now automatically parses the 
referring page. That means that Betsie now allows you to link to her 
directly, like this:

<A HREF="http://www.yoursite.com/cgi-bin/parser.pl">Text-only</A>

The ideal situation for such a text-only link is the top left hand corner
of the page. If it is anywhere else, the chances are slim that the very
users who need to find it will be able to.

LIMITATIONS
-----------

1 - Betsie is written in Perl. Not Magic.

That is to say, Betsie cannot magically solve problems caused by dodgy
HTML code. If there are pages in your site that do not validate as
proper HTML, then you'd better fix that or some of them *may* make
Betsie fall over. Actually, you'd better fix that anyway, even if you
choose not to use Betsie in the end.

2 - Betsie has no editorial control over your site. You do. That
includes the ALT attributes of your IMG tags.

No matter how much you and your organisation may have been in denial
about the contents of the ALT attributes of your IMG tags in the past,
now is the time to face up to the fact that all that text has to make
sense unless you want to have some pages that come across as really
obtuse when viewed with Betsie. Or Lynx. Or with images turned off in a
graphical browser.

3 - Betsie is not an excuse to continue making inaccessible pages.

Betsie acts in two ways to increase the accessibility of your site.
Firstly, it can eliminate standardised inaccessible features such as a
long left hand navbar in one fell swoop. Secondly, it forces those
maintaining large sites to examine their accessibility and to introduce
accessiblity as a compulsory feature of new pages as and when they
arise. If you keep adding new inaccessible pages and features, then
eventually, Betsie will stop being able to deal with them.

VERSION CHANGES
---------------

See ChangeLog.

MORE INFORMATION
----------------

Betsie Website

The Betsie website is on the following URL:

http://www.bbc.co.uk/education/betsie/

and contains a good deal of further information about Betsie, including
up to date contact details, the latest version of the free source
distribution and more.

There is also now a Betsie developers site on:

http://betsie.sourceforge.net/

From there you can always get the very latest development version of
Betsie via CVS.

There is also a Betsie development mailing list, details of which are
available here:

http://lists.sourceforge.net/lists/listinfo/betsie-devel

The list is very low traffic, and subscribing is highly recommended in
order to remain up-to-date with the latest version of Betsie.

Meanwhile, I hope you find Betsie useful, and look forward to receiving
your comments, criticisms and recipes for small sweet things.

Cheers etc.,

Wayne Myers, 19th April, 2001
wayne.myers@bbc.co.uk

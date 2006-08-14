#!/usr/bin/perl

package Mail::Summary::Tools;

our $VERSION = "0.01";

__PACKAGE__;

__END__

=pod

=head1 NAME

Mail::Summary::Tools - Tools for mailing list summarization.

=head1 SYNOPSIS
	
	# create a summary from anything Mail::Box can open.
	# you may also programatically create summary objects and serialize
	# them if you don't have the threads in a standard mail format.

	% mailsum create --dates --posters --clean -i foo.mbox -o summary.yaml


	# edit the text in your editor, if you don't like YAML files

	% mailsum edit --skip --dates --posters --links --archive gmane summary.yaml


	# create pretty outputs

	% mailsum totext --shorten -a google summary.yaml > summary.txt
	% mailsum tohtml --archive google summary.yaml > summary.html

=head1 DESCRIPTION

This distribution contains numerous classes useful for creating summaries, and
an L<App::CLI> based frontend to those classes.

The main usage is illustrated in the L</SYNOPSIS> section.

=head1 WORKFLOW

In the first step L<Mail::Summary::Tools> takes a mail box of any sort as
input, and creates a YAML file for the summary. This file contains a hierarchal
structure whereby every thread belongs to exactly one list (cross posts should
not be summarized twice), and lots of meta data is also maintained.

This file may be hand edited if you're comfortable with YAML, but typically you
use the flat file format, exposed using the C<edit> command to alter the
summary texts, hide threads, assign threads to a different list, etc. This can
be done either interactively (with L<Proc::InvokeEditor>) or using --save and
--load.

If any updating of the summary is necessary you should load all the changes you
have using the edit command, and run C<create --update> (it needs a better
name). Out of date threads will be marked as long as you use the --dates option
(if a thread is summarized and it's end date is extended by the update then it
is marked out of date).

When you are done you can emit using C<totext> and C<tohtml>. The default
outputs assume that the summary text is written in the markdown language. This
translates well to HTML, and looks pretty good as-is in plain text.

=head1 COMPONENTS

These are the main components of this distribution:

=head2 L<Mail::Summary::Tools::Summary>

The model for summary objects

=head2 L<Mail::Summary::Tools::FlatFile>

Export and load L<Mail::Summary::Tools::Summary> fields from a convenient
flatfile format.

=head2 L<Mail::Summary::Tools::Output>

The various output formats, like plain text, HTML.

=head2 L<Mail::Summary::Tools::CLI>

The L<App::CLI> based components

=head2 L<Mail::Summary::Tools::ArchiveLink>

Classes for creating links to mailing list archives (google groups, gmane,
etc).

=head1 FUTURE DIRECTIONS

Here are a few possible extensions to this project which we may or may not get
around to:

=over 4

=item *

Long term persistence of thread status - what has been summarised, what needs
revisiting, etc, based on a config + state file per mailing list.

=item *

Archive downloading tools, for backlogging, possibly based on L<Net::NNTP> or
L<WWW::Google::Groups>.

This is important for offline viewing.

=item *

A local running webapp to streamline summarization.

=item *

Posting interface - Atom (for blogs), use.perl.org, and to various mailing
lists.

=item 

=back

=head1 SEE ALSO

L<Mail::Box>, L<App::CLI>, L<Template>, L<Proc::InvokeEditor>, L<YAML>, L<YAML::Syck>.

=head1 AUTHORS

Yuval Kogman, E<lt>nothingmuch@woobling.orgE<gt>

Ann Barcomb

=head1 COPYRIGHT & LICENSE

Copyright 2006 by Yuval Kogman E<lt>nothingmuch@woobling.orgE<gt>, Ann Barcomb

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

=cut


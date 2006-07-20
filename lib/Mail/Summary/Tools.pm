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

=cut



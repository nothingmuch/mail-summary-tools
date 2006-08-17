#!/usr/bin/perl

package Mail::Summary::Tools::CLI::ToHTML;
use base qw/App::CLI::Command/;

use strict;
use warnings;

use Mail::Summary::Tools::Summary;
use Mail::Summary::Tools::Output::HTML;

use constant options => (
	'v|verbose'       => "verbose",
    'i|input=s'       => 'input',    # required, string
    'o|output:s'      => 'output',   # defaults to '-'
    'a|archive:s'     => 'archive',  # defaults to 'google'
	'h1:s'            => 'h1',
	'h2:s'            => 'h2',
	'h3:s'            => 'h3',
);

sub template_output {
    my $self = shift;
    
    if ( !$self->{output} or $self->{output} eq '-' ) {
        return \*STDOUT;
    } elsif ( my $file = $self->{output} ) {
        open my $fh, ">", $file or die "Couldn't open output (open($file): $!)\n";
        return $fh;
    }
}

sub run {
	my ( $self, @args ) = @_;
	@args and $self->{$_} ||= shift @args for qw/input output/;

    my $summary = Mail::Summary::Tools::Summary->load(
        $self->{input} || die("You must supply a summary YAML file to textify.\n"),
        thread => {
            default_archive => $self->{archive} || "google",
			archive_link_params => { cache => $self->{context}->cache },
        },
    );

	my $o = Mail::Summary::Tools::Output::HTML->new(
		summary => $summary,
		map { defined($self->{$_}) ? ( "${_}_tag" => [ split ',', $self->{$_} ] ) : () } qw/h1 h2 h3/,
	);

	my $out = $self->template_output;
	binmode $out, ':utf8';
	print $out $o->process;
}

__PACKAGE__;

__END__
=pod

=head1 USAGE

	tohtml --input summary.yaml > foo.html

=head1 OPTIONS

	--verbose                   Not yet implemented.
	--input=FILE.yml            Which summary to process
	--output                    Where to output. Defaults to '-', which is stdout.
	--archive=SERVICE           Which archival service to link to. "google" or "gmane".
	--h1=tag,tag                Override the default tag for heading tags.  Accepts a
	                            list of tags, such that p,b becomes <p><b>...</b></p>
	--h2                        see --h1
	--h3                        see --h1

=head1 DESCRIPTION

Emits HTML output from the YAML summary.

=cut


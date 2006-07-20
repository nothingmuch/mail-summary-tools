#!/usr/bin/perl

package Mail::Summary::Tools::CLI::Edit;
use base qw/App::CLI::Command/;

use strict;
use warnings;

use Mail::Summary::Tools::Summary;
use Mail::Summary::Tools::FlatFile;
use Proc::InvokeEditor;

use constant options => (
	'v|verbose'   => 'verbose',
	'i|input=s'   => 'input',
	'a|archive:s' => 'archive',  # defaults to 'google'
	'p|posters'   => 'posters',
	's|skip'      => 'skip',
	'l|links'     => 'links',
	'd|dates'     => 'dates',
);

sub run {
	my ( $self, @args ) = @_;
	@args and $self->{$_} = shift @args for qw/input/;

    my $summary = Mail::Summary::Tools::Summary->load(
        $self->{input} || die("You must supply a summary YAML file to edit.\n"),
        thread => {
            default_archive => $self->{archive} || "google",
        },
	);

	my $flat = Mail::Summary::Tools::FlatFile->new(
		summary         => $summary,
		skip_summarized => $self->{skip},
		list_posters    => $self->{posters},
		list_dates      => $self->{dates},
		add_links       => $self->{links} || !!$self->{archive},
	);

	$flat->load( scalar(Proc::InvokeEditor->edit( $flat->save )) );

	$summary->save( $self->{input} );
}

__PACKAGE__;

__END__

=pod

=head1 USAGE

	edit -lp summary.yaml

=head1 OPTIONS

	--verbose                   Not yet implemented.
	--input=FILE.yml            The file to edit.
	--posters                   List all the posters in a thread.
	--links                     Add links to the default archive.
	--archive=SERVICE           Which archival service to link to. "google" or "gmane".

=cut



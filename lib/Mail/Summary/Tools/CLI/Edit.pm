#!/usr/bin/perl

package Mail::Summary::Tools::CLI::Edit;
use base qw/App::CLI::Command/;

use strict;
use warnings;

use Mail::Summary::Tools::Summary;
use Mail::Summary::Tools::FlatFile;
use Proc::InvokeEditor;
use File::Slurp;

use constant options => (
	'v|verbose'      => 'verbose',
	'i|input=s'      => 'input',
	'a|archive:s'    => 'archive',  # defaults to 'google'
	'p|posters'      => 'posters',
	's|skip'         => 'skip',
	'l|links'        => 'links',
	'd|dates'        => 'dates',
	'm|misc'         => 'misc',
	'save'           => "save",
	'load'           => "load",
	'extra_fields:s' => "extra_fields",
);

sub run {
	my ( $self, @args ) = @_;
	@args and $self->{$_} ||= shift @args for qw/input/;

    my $summary = Mail::Summary::Tools::Summary->load(
        $self->{input} || die("You must supply a summary YAML file to edit.\n"),
        thread => {
            default_archive => $self->{archive} || "google",
			archive_link_params => { cache => $self->{context}->cache },
        },
	);

	my $flat = Mail::Summary::Tools::FlatFile->new(
		summary         => $summary,
		skip_summarized => $self->{skip},
		list_posters    => $self->{posters},
		list_dates      => $self->{dates},
		list_misc       => $self->{misc},
		add_links       => $self->{links} || !!$self->{archive},
		extra_fields    => [ split ',', $self->{extra_fields} || '' ],
	);

	die "You can either save or load, not both at once" if $self->{load} && $self->{save};

	if ( $self->{save} ) {
		my $out;
		if ( @args ) {
			open $out, ">", $args[0] or die "open($args[0]): $!";
		} else {
			$out = \*STDOUT;
		}
		print $out $flat->save;
	} elsif ( $self->{load} ) {
		local $/;
		local @ARGV = @args;
		$flat->load(scalar(<>));
		$summary->save( $self->{input} );
	} else {
		$flat->load( scalar(Proc::InvokeEditor->edit( $flat->save )) );
		$summary->save( $self->{input} );
	}
}

__PACKAGE__;

__END__

=pod

=head1 USAGE

	edit -lp summary.yaml
	edit --save summary.yaml > out.txt
	edit --load summary.yaml < in.txt

=head1 OPTIONS

	--verbose                   Not yet implemented.
	--input=FILE.yml            The file to edit.
	--posters                   List all the posters in a thread.
	--links                     Add links to the default archive.
	--archive=SERVICE           Which archival service to link to. "google" or "gmane".
	--misc                      List misc data (e.g. RT tickets)

=cut



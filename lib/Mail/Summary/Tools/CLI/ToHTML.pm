#!/usr/bin/perl

package Mail::Summary::Tools::CLI::ToHTML;
use base qw/Mail::Summary::Tools::CLI::Command/;

use strict;
use warnings;

use Class::Autouse (<<'#\'END_USE' =~ m!(\w+::[\w:]+)!g);
#\

use Mail::Summary::Tools::Summary;
use Mail::Summary::Tools::Output::HTML;

#'END_USE

use constant options => (
	[ 'verbose|v!'      => "Output verbose information" ],
    [ 'input|i=s'       => 'The summary YAML file to emit' ],
    [ 'output|o=s'      => 'A file to output to (defaults to STDOUT)' ],
    [ 'archive|a=s'     => 'On-line archive to use', { default => "google" } ],
	#[ 'compact|c'       => 'Emit compact HTML (no <div> tags, etc)' ],
	#[ 'body|b'          => 'Emit body fragment only (as opposed to a full, valid document)' ],
	[ 'h1=s@'           => 'Tags to use instead of h1 (e.g. --h1 p,b emits <p><b>heading</b></p>)', { default => ["h1"] } ],
	[ 'h2=s@'           => 'see h1', { default => ["h2"] } ],
	[ 'h3=s@'           => 'see h1', { default => ["h3"] } ],
);

sub template_output {
    my $self = shift;
	my $opt = $self->{opt};
    
    if ( !$opt->{output} or $opt->{output} eq '-' ) {
        return \*STDOUT;
    } elsif ( my $file = $opt->{output} ) {
        open my $fh, ">", $file or die "Couldn't open output (open($file): $!)\n";
        return $fh;
    }
}

sub validate {
	my ( $self, $opt, $args ) = @_;
	@$args and $opt->{$_} ||= shift @$args for qw/input output/;

	unless ( $opt->{input} ) {
		$self->usage_error("Please specify an input summary YAML file.");
	}
	
	if ( @$args ) {
		$self->usage_error("Unknown arguments: @$args.");
	}

	foreach my $tag ( qw/h1 h2 h3/ ) {
		@{ $opt->{$tag} } = map { split ',' } @{ $opt->{$tag} };
	}

	$self->{opt} = $opt;
}

sub run {
	my ( $self, $opt, $args ) = @_;

    my $summary = Mail::Summary::Tools::Summary->load(
        $opt->{input},
        thread => {
            default_archive => $opt->{archive} || "google",
			archive_link_params => { cache => $opt->{context}->cache },
        },
    );

	my $o = Mail::Summary::Tools::Output::HTML->new(
		summary => $summary,
		map { $_ . "_tag" => $opt->{$_} } qw/h1 h2 h3/,
	);

	my $out = $self->template_output;
	binmode $out, ':utf8';
	print $out $o->process;
}

__PACKAGE__;

__END__
=pod

=head1 NAME

Mail::Summary::Tools::CLI::ToHTML - Emit a formatted HTML summary

=head1 SYNOPSIS

	# see command line usage

=head1 DESCRIPTION

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

=head1 NAME

Mail::Summary::Tools::CLI::ToHTML - 

=head1 SYNOPSIS

	use Mail::Summary::Tools::CLI::ToHTML;

=head1 DESCRIPTION

=cut


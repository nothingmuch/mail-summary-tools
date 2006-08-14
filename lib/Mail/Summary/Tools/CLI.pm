#!/usr/bin/perl

package Mail::Summary::Tools::CLI;
use base qw/App::CLI/;

use Mail::Summary::Tools::CLI::Context;

use strict;
use warnings;

use constant alias => (
	totext => "ToText",
	tohtml => "ToHTML",
);

sub get_cmd {
	my $self = shift;
	my $cmd = $self->SUPER::get_cmd(@_);
	$cmd->{context} = $self->make_context,
	$cmd;
}

sub make_context {
	my $self = shift;
	Mail::Summary::Tools::CLI::Context->new();
}

__PACKAGE__;

__END__

=pod

=head1 NAME

Mail::Summary::Tools::CLI - App::CLI based mailing list summarization tool.

=head1 SYNOPSIS

	use Mail::Summary::Tools::CLI;

=head1 DESCRIPTION

=cut



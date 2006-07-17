#!/usr/bin/perl

package Mail::Summary::Tools::CLI::ToText;
use base qw/App::CLI::Command/;

use strict;
use warnings;

use Mail::Summary::Tools::Summary;
use Mail::Summary::Tools::Output::TT;

use Text::Wrap ();

# --shorten=Shorl
# -s # defaults to xrl.us

# Currently works like this:
# --sh foo          # to use foo (-s implied)
# -s                # to shorten with Metamark

# If you were to do:  
# my $shorten = 'a';
# GetOptions("shorten:s" => \$shorten);
# -s   # gives empty string
#      # gives a
# -s f # gives f
# but I don't know if you want to do that, it might be annoying.
use constant options => (
    'shorten:s'       => 'shorten',
    'input=s'         => 'input',    # required, string
    'output:s'        => 'output',   # defaults to '-'
    'archive:s'       => 'archive',  # defaults to 'google'
    'template:s'      => 'template', # defaults to '', which means __DATA__
    'columns:i'       => 'columns',  # defaults to 80
    'wrap_overflow:b' => 'wrap_overflow', # whether or not to force wrapping of overflowing text
);

sub wrap {
    my ( $self, $text, $columns, $first_indent, $rest_indent ) = @_;

    $columns ||= 80;
    $first_indent ||= '    ';
    $rest_indent  ||= '    ';

    no warnings 'once';
    local $Text::Wrap::huge = $self->_wrap_huge;
    
    Text::Wrap::wrap( $text, $self->{columns}, $first_indent, $rest_indent );
}

sub bullet {
    my ( $self, $text, $columns ) = @_;
    $self->wrap( $text, $columns, '  * ', '    ' );
}

sub _wrap_huge {
    my $self = shift;
    return $self->{wrap_overflow} ? 'wrap' : 'overflow'; # default to not breaking URIs
}

sub shorten {
    my ( $self, $uri ) = @_;

	if ( $self->should_shorten($uri) ) {
	   $self->really_shorten( $uri );
	} else {
		return $uri;
	}
}

sub really_shorten {
    my ( $self, $uri ) = @_;
    
    my $service = $self->{shorten} || 'Metamark';
    
    $service ||= "Metamark";
    eval "require WWW::Shorten::$service";
    no strict 'refs';
    &{"WWW::Shorten::${service}::makeashorterlink"}($uri);
}

sub shortening_enabled {
    my ( $self, $uri ) = @_;
    if ( $self->{shorten} or $self->{shorten} eq '' ) { # Getopt will give 0 when unused
        return 1;
    } else {
        return;
    }
}

sub should_shorten {
    my ( $self, $uri ) = @_;
    return unless $self->shortening_enabled;

    length($uri) > 40 || $uri =~ /gmane|groups\.google/
}

sub template_input {
    my $self = shift;

    if ( my $file = $self->{template} ) {
        open my $fh, "<", $file or die "Couldn't open template (open($file): $!)\n";
        return $fh;
    } else {
        return \*DATA;
    }
}

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

    $self->load_summary( $self->{summary} );
    my $summary = Mail::Summary::Tools::Summary->load(
        $self->{input} || die "You must supply a summary YAML file to textify.\n",
        thread => {
            default_archive => $self->{archive} || "google",
        },
    );

    {
        no warnings 'once';
        local $Text::Wrap::huge = "overflow";
    
        my $o = Mail::Summary::Tools::Output::TT->new( template_input => 'txt.tt' );
    
        $o->process(
            $summary,
            {
                shorten => sub { $self->shorten(shift) },
                wrap    => sub { $self->wrap(shift) },
                bullet  => sub { $self->bullet(shift) },
            },
        );
    }
}


__PACKAGE__;

=pod

=head1 NAME

Mail::Summary::Tools::CLI::ToText - 

=head1 SYNOPSIS

	totext --shorten --input summary.yaml

=head1 OPTIONS

	--input                     Which summary to process
	--output                    Where to output. Defaults to '-', which is stdout.
	--archive=SERVICE           Which archival service to link to. "google" or "gmane".
	--shorten[=SERVICE]         Shorten long URIs in the text output. You can
	                            specify a WWW::Shorten service.
	--template=FILE             Use this template instead of the deafult one 
	--columns=NCOLS             For text wrapping.
	--wrap_overflow             Whether or not to force wrapping of overflowing text.

=cut

__DATA__
[% summary.title %]
[% FOREACH list IN summary.lists %]
 [% list.title %]
[% IF list.extra.description %]
[% wrap(list.extra.description) %]
[% END %][% FOREACH thread IN list.threads %]
[% head = BLOCK %][% thread.subject %] <[% shorten(thread.archive_link.thread_uri) %]>[% END %][% wrap(head) %]

[% IF thread.summary %][% wrap(thread.summary) %]
[% ELSE %]    Participants:[% FOREACH participant IN thread.extra.participants %]
    - [% participant.name %][% END %]
[% END %][% END %][% END %]
[% IF summary.extra.see_also %]

 See Also
[% FOREACH item IN summary.extra.see_also %]
[% link = BLOCK %][% item.name %] <[% shorten(item.uri ) %]>[% END %][% bullet(link) %]
[% END %]
[% END %]

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
	'v|verbose'       => "verbose",
    's|shorten:s'     => 'shorten',
    'i|input=s'       => 'input',    # required, string
    'o|output:s'      => 'output',   # defaults to '-'
    'a|archive:s'     => 'archive',  # defaults to 'google'
    't|template:s'    => 'template', # defaults to '', which means __DATA__
    'c|columns:i'     => 'columns',  # defaults to 80
    'w|wrap_overflow' => 'wrap_overflow', # whether or not to force wrapping of overflowing text
);

sub wrap {
    my ( $self, $text, $columns, $first_indent, $rest_indent ) = @_;

    $columns ||= $self->{columns} || 80;
    $first_indent ||= '    ';
    $rest_indent  ||= '    ';

	$text =~ s/<(\w+:.*?)>/$self->expand_uri($1)/ge;

    no warnings 'once';
    local $Text::Wrap::huge = $self->_wrap_huge;
    local $Text::Wrap::columns = $columns;

    Text::Wrap::fill( $first_indent, $rest_indent, $text );
}

sub bullet {
    my ( $self, $text, $columns ) = @_;
    $self->wrap( $text, $columns, '  * ', '    ' );
}

sub heading {
    my ( $self, $text, $columns ) = @_;
    $self->wrap( $text, $columns, '  ', '  ' );
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

sub rt_uri {
	my ( $self, $rt, $id ) = @_;

	if ( $rt eq "perl" ) {
		return $self->shorten("http://rt.perl.org/rt3/Ticket/Display.html?id=$id");
	} else {
		die "unknown rt installation: $rt";
	}
}

sub expand_uri {
	my ( $self, $uri_text ) = @_;

	my $uri = URI->new($uri_text);

	if ( $uri->scheme eq 'rt' ) {
		my ( $rt, $id ) = ( $uri->authority, substr($uri->path, 1) );
	   	my $rt_uri = $self->rt_uri($rt, $id);
		return "[$rt #$id] <$rt_uri>";
	} else {
		return "<$uri>"; # markdown will auto linkfy
	}
}

sub really_shorten {
    my ( $self, $uri ) = @_;
    
    my $service = $self->{shorten} || 'Metamark';
    
	my $mod = "WWW::Shorten::$service";
	unless ( $mod->can("makeashorterlink") ) {
		my $file = join("/", split("::", $mod ) ) . ".pm";
		require $file;
	}

    no strict 'refs';
    my $short = &{"${mod}::makeashorterlink"}( $uri ) || $uri;
	return $short;
}

sub shortening_enabled {
    my ( $self, $uri ) = @_;
    if ( $self->{shorten} or defined($self->{shorten}) and $self->{shorten} eq '' ) { # Getopt will give 0 when unused
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
	@args and $self->{$_} = shift @args for qw/input output/;

    my $summary = Mail::Summary::Tools::Summary->load(
        $self->{input} || die("You must supply a summary YAML file to textify.\n"),
        thread => {
            default_archive => $self->{archive} || "google",
        },
    );

	my $o = Mail::Summary::Tools::Output::TT->new( template_input => $self->template_input );

	$o->process(
		$summary,
		{
			shorten => sub { $self->shorten(shift) },
			wrap    => sub { $self->wrap(shift) },
			bullet  => sub { $self->bullet(shift) },
			heading => sub { $self->heading(shift) },
		},
	);
}

__PACKAGE__;

=pod

=head1 USAGE

	totext --shorten --input summary.yaml

=head1 OPTIONS

	--verbose                   Not yet implemented.
	--input=FILE.yml            Which summary to process
	--output                    Where to output. Defaults to '-', which is stdout.
	--archive=SERVICE           Which archival service to link to. "google" or "gmane".
	--shorten[=SERVICE]         Shorten long URIs in the text output. You can
	                            specify a WWW::Shorten service.
	--template=FILE             Use this template instead of the deafult one 
	--columns=NCOLS             For text wrapping. Defaults to 80.
	--wrap_overflow             Whether or not to force wrapping of overflowing text.

=cut

__DATA__
[% summary.title %]
[% FOREACH list IN summary.lists %]
 [% list.title %]
[% IF list.extra.description %]
[% wrap(list.extra.description) %]
[% END %][% FOREACH thread IN list.threads %]
[% head = BLOCK %][% thread.subject %] <[% shorten(thread.archive_link.thread_uri) %]>[% END %][% heading(head) %]

[% IF thread.summary %][% wrap(thread.summary) %]
[% ELSE %]    Posters:[% FOREACH participant IN thread.extra.posters %]
    - [% participant.name %][% END %]
[% END %][% END %][% END %]
[% IF summary.extra.see_also %]
 See Also
[% FOREACH item IN summary.extra.see_also %]
[% link = BLOCK %][% item.name %] <[% shorten(item.uri ) %]>[% END %][% bullet(link) %]
[% END %]
[% END %]

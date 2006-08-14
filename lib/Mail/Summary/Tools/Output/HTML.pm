#!/usr/bin/perl

package Mail::Summary::Tools::Output::HTML;
use Moose;

use Mail::Summary::Tools::Output::TT;
use Text::Markdown ();
use HTML::Entities;

has summary => (
	isa => "Mail::Summary::Tools::Summary",
	is  => "rw",
	required => 1,
);

has description => (
	isa => "Str",
	is  => "rw",
	default => "Mailing list summary",
);

has generator => (
	isa  => "Str",
	is   => "rw",
	lazy => 1,
	default => sub {
		my $self = shift;
		require Mail::Summary::Tools;
		return __PACKAGE__ . " version $Mail::Summary::Tools::VERSION";
	},
);

has template_config => (
	isa => "HashRef",
	is  => "rw",
	default => sub { return {} },
);

has template_obj => (
	isa => "Template",
	is  => "rw",
	lazy => 1,
	default => sub { Template->new( $_[0]->template_config ) },
);

sub process {
	my $self = shift;

	$self->template_snippet(
		$self->main_template,
		html => $self,
	);
}

sub template_snippet {
	my ( $self, $snippet, %vars ) = @_;
	
	my $out;	

	my $tt = $self->template_obj;

	$tt->process(
		\$snippet,
		{
			%vars,
			html => $self,
		},
		\$out,		
	) || warn $tt->error . " in $snippet";

	return $out;
}

sub markdown {
	my ( $self, $text ) = @_;

	$text =~ s/<((?:msgid|rt):\S+?)>/$self->expand_uri($1)/ge;
	$text =~ s/\[(.*?)\]\(((?:msgid|rt):\S+?)\)/$self->expand_uri($2, $1)/ge;

	# non ascii stuff gets escaped (accents, etc), but not punctuation, which
	# markdown will handle for us.
	$text = $self->escape_html($text, '^\p{IsASCII}');

	Text::Markdown::markdown( $text );
}

sub rt_uri {
	my ( $self, $rt, $id ) = @_;
	
	if ( $rt eq "perl" ) {
		return "http://rt.perl.org/rt3/Public/Bug/Display.html?id=$id";
	} else {
		die "unknown rt installation: $rt";
	}
}

sub link_to_message {
	my ( $self, $message_id, $text ) = @_;

	my $thread = $self->summary->get_thread_by_id( $message_id ) || die "$message_id is not in summary";

	my $uri;
	
	if ( $thread->hidden ) {
		$uri = $thread->archive_link->thread_uri;
	} else {
		$uri = URI->new;
		$uri->fragment($message_id);
	}

	$text ||= $thread->subject;

	"[$text]($uri)";
}

sub expand_uri {
	my ( $self, $uri_string, $text ) = @_;

	my $uri = URI->new($uri_string);

	if ( $uri->scheme eq 'rt' ) {
		my ( $rt, $id ) = ( $uri->authority, substr($uri->path, 1) );
	   	my $rt_uri = $self->rt_uri($rt, $id);
		$text ||= "[$rt #$id]";
		return "[$text]($rt_uri)";
	} elsif ( $uri->scheme eq 'msgid' ) {
		return $self->link_to_message( join("", grep { defined } $uri->authority, $uri->path), $text );
	} else {
		die "unknown uri scheme: $uri";
	}
}

sub escape_html {
	my ( $self, $text, @extra ) = @_;
	HTML::Entities::encode_entities($text, @extra);
}	

has h1_tag => (
	isa => "ArrayRef",
	is  => "rw",
	auto_deref => 1,
	default => ["h1"],
);

sub wrap_tags {
	my ( $self, $tags, @text ) = @_;

	if ( @$tags ) {
		my ( $outer, @inner ) = @$tags;
		return "<$outer>" . $self->wrap_tags( \@inner, @text ) . "</$outer>";
	} else {
		return "@text";
	}
}

sub h1 {
	my ( $self, @inner ) = @_;
	my $tag = $self->h1_tag;
	$self->wrap_tags( $tag, @inner );
}

has h2_tag => (
	isa => "ArrayRef",
	is  => "rw",
	auto_deref => 1,
	default => ["h2"],
);

sub h2 {
	my ( $self, @inner ) = @_;
	my $tag = $self->h2_tag;
	$self->wrap_tags( $tag, @inner );
}

has h3_tag => (
	isa => "ArrayRef",
	is  => "rw",
	auto_deref => 1,
	default => ["h3"],
);

sub h3 {
	my ( $self, @inner ) = @_;
	my $tag = $self->h3_tag;
	$self->wrap_tags( $tag, @inner );
}

sub toc {
	my $self = shift;
	return ();
}

sub body {
	my $self = shift;

	return qq{<div id="summary_container">\n}
	. join("\n\n\n",
		$self->header,
		$self->lists,
		$self->footer,
	)
	. qq{</div>\n};
}

sub header {
	my $self = shift;
	my @parts;
	
	return qq{<div id="summary_header">\n}
	. join("\n\n",
		$self->h1( $self->escape_html( $self->summary->title || "Mailing list summary" ) ),
		$self->custom_header,
	)
	. qq{</div>\n};
}

sub custom_header {
	my $self = shift;

	if ( my $header = eval { $self->summary->extra->{header} } ) {
		return join("\n\n", map { $self->custom_header_section( $_ ) } @$header );
	} else {
		return ();
	}
}

sub custom_header_section {
	my ( $self, $section ) = @_;
	return qq{<div class="header_section">\n}
	. $self->generic_custom_section( $section )
	. qq{</div>\n};
}

sub footer {
	my $self = shift;
	
	return qq{<div id="summary_footer">\n}
	. join("\n\n",
		$self->custom_footer,
		$self->see_also,
	)
	. qq{</div>\n};
}

sub custom_footer {
	my $self = shift;

	if ( my $footer = eval { $self->summary->extra->{footer} } ) {
		return join("\n\n", map { $self->custom_footer_section( $_ ) } @$footer );
	} else {
		return ();
	}
}

sub custom_footer_section {
	my ( $self, $section ) = @_;
	return qq{<div class="footer_section">\n}
	. $self->generic_custom_section( $section )
	. qq{</div>\n}
}

sub generic_custom_section {
	my ( $self, $section ) = @_;

	return join("\n\n",
		$self->h2( $self->escape_html($section->{title}) ),
		$self->markdown( $section->{body} ),
	)
}

sub see_also {
	my $self = shift;

	if ( my $see_also = eval { $self->summary->extra->{see_also} } ) {
		return qq{<div class="footer_section" id="see_also">\n}
		. join("\n\n",
			$self->see_also_heading($see_also),
			$self->see_also_links($see_also),
		)
		. qq{\n</div>\n};
	} else {
		return ();
	}
}

sub see_also_heading {
	my ( $self, $see_also ) = @_;
	$self->h2("See Also");
}	

sub see_also_links {
	my ( $self, $see_also ) = @_;	

	join("\n",
		"<ul>",
		( map { "<li>".$self->see_also_link($_)."</li>" } @$see_also ),
		"</ul>",
	);
}

sub see_also_link {
	my ( $self, $item ) = @_;
	sprintf '<a href="%s">%s</a>', map { $self->escape_html($_) } $item->{uri}, $item->{name};
}

sub lists {
	my $self = shift;

	return qq{<div id="summary_container_body">\n}
	. join("\n\n\n", map { $self->list($_) } $self->summary->lists)
	. qq{</div>\n};
}

sub list {
	my ( $self, $list ) = @_;

	my $name = $list->name;
	$name =~ s/[^\w]+/_/g;

	return qq{<div class="summary_list" id="summary_list_$name">\n}
	. join("\n\n",
		$self->list_header($list),
		$self->list_body($list),
		$self->list_footer($list),
	)
	. qq{</div>\n};
}

sub list_header {
	my ( $self, $list ) = @_;

	return join("\n\n",
		$self->list_heading($list),
		$self->list_description($list),
	);
}

sub list_heading {
	my ( $self, $list ) = @_;
	$self->h2( $self->list_title($list) || return, $self->list_heading_extra );
}

sub list_heading_extra {
	my ( $self, $list ) = @_;
	# e.g. " (perl6-compiler)"... maybe $list->extra->{remark} || $list->name
	return;
}

sub list_title {
	my ( $self, $list ) = @_;

	my $title = $list->title || $list->name || return;

	if ( my $uri = eval { $list->extra->{uri} } ) {
		return sprintf '<a href="%s">%s</a>', map { $self->escape_html($_) } $uri, $title,
	} else {
		return $self->escape_html($title);
	}
}

sub list_description {
	my ( $self, $list ) = @_;

	if ( my $description = eval { $list->extra->{description} } ) {
		$self->markdown( $description );
	} else {
		return;
	}
}

sub list_body {
	my ( $self, $list ) = @_;

	my $name = $list->name;
	$name =~ s/[^\w]+/_/g;

	return qq{<div class="summary_list_body" id="summary_list_body_$name">\n}
	. join("\n\n", map { $self->thread($_) } $list->threads)
	. qq{</div>\n};
}

sub list_footer {
	my ( $self, $list ) = @_;
	return ();
}

sub thread {
	my ( $self, $thread ) = @_;

	return if $thread->hidden;

	return qq{<div class="thread_summary">\n}
	. join("\n\n",
		$self->thread_header($thread),
		$self->thread_body($thread),
		$self->thread_footer($thread),
	)
	. qq{</div>\n};
}

sub thread_header {
	my ( $self, $thread ) = @_;
	$self->h3( $self->thread_link($thread) );
}

sub thread_link {
	my ( $self, $thread ) = @_;

	my $uri = $thread->archive_link->thread_uri;

	sprintf '<a href="%s" name="%s">%s</a>', map { $self->escape_html($_) } $uri, $thread->message_id, $thread->subject,
}

sub thread_body {
	my ( $self, $thread ) = @_;

	if ( my $summary = $thread->summary ) {
		return qq{<div class="thread_summary_body">\n}
		. $self->markdown($summary)
		. qq{</div>\n};
	} else {
		return qq{<div class="thread_summary_body empty_thread_summary_body">\n}
		. $self->thread_body_no_summary($thread)
		. qq{</div>\n};
	}
}

sub thread_body_no_summary {
	my ( $self, $thread ) = @_;

	my $posters = eval { $thread->extra->{posters} };

	join("\n",
		'<p>No summary provided.</p>',
		($posters ? $self->thread_posters($posters) : ()),
	);
}

sub thread_posters {
	my ( $self, $posters ) = @_;

	join("\n",
		"<p>The following people participated in this thread:</p>",
		"<ul>",
		( map { "<li>" . $self->escape_html($_->{name} || $_->{email}) . "</li>" } @$posters ),
		"</ul>",
	);
}

sub thread_footer {
	my ( $self, $thread ) = @_;
	return ();
}

sub css {
	my $self = shift;
	return ();
}

use constant main_template => <<'TMPL';
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
	<head>
		<title>[% summary.title | html %]</title>
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
		<meta name="description" content="[% html.description | html %]" />
		<meta name="generator" content="[% html.generator | html %]" />
		[% html.css %]
	</head>
	<body>
		[% html.toc %]
		[% html.body %]
	</body>
</html>
TMPL

__PACKAGE__;

__END__

=pod

=head1 NAME

Mail::Summary::Tools::Output::HTML - 

=head1 SYNOPSIS

	use Mail::Summary::Tools::Output::HTML;

=head1 DESCRIPTION

=cut

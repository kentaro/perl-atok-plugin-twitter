package Atok_plugin;
use strict;
use warnings;
use utf8;
use Template;
use Config::Pit;
use Net::Twitter;

my $dispatch_table = {
    qr/(?:ついったー|たいむらいん|TL)/i => 'friends_timeline',
};

sub run_process {
    my $params = shift;
    my $method;

    for my $regex (keys %$dispatch_table) {
        if ($params->{composition_string} =~ /$regex/) {
            $method = $dispatch_table->{$regex};
            last;
        }
    }

    return if !$method;;
    return (candidate => __PACKAGE__->$method());
}

sub friends_timeline {
    my $self      = shift;
    my $client    = get_client();
    my $candidate = [];

    for my $friend (@{$client->friends_timeline || []}) {
        my $tweet = ATOK::Plugin::Twitter::Tweet->new($friend);
        push @$candidate, $tweet->to_hash;
    }

    $candidate;
}

sub get_client {
    my $config = pit_get('twitter.com');
    my $username = $config->{username}
        or die qq{usernameというキーでtwitterのアカウントを設定してください。};
    my $password = $config->{password}
        or die qq{passwordというキーでtwitterのパスワードを設定してください。};

    Net::Twitter->new(
        traits     => [qw(API::REST)],
        username   => $username,
        password   => $password,
        clientname => 'ATOK::Plugin::Twitter',
    );
}

package ATOK::Plugin::Twitter::Tweet;
use base qw(Class::Accessor::Lvalue::Fast);
__PACKAGE__->mk_accessors(qw(
    id
    tt
));

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
       $self->tt = Template->new;
       $self;
}

sub user {
    my $self = shift;
    $self->{_user} ||= ATOK::Plugin::Twitter::User->new($self->{user});
}

sub url {
    my $self = shift;
    sprintf 'http://twitter.com/%s/%d', $self->user->screen_name, $self->id;
}

sub to_hash {
    my $self = shift;
    +{
        hyoki => sprintf('@%s (%s)', $self->user->screen_name, $self->user->name),
        comment_xhtml => $self->to_xhtml,
        alternative   => $self->url,
        alternative_alias=> 'この発言をブラウザで開く',
        alternative_type => 'url_jump_string',
    }
}

sub to_xhtml {
    my $self = shift;
    my $template = $self->template;
    $self->tt->process(\$template, $self, \my $result);
    $result;
}

sub template {
    return <<'EOS'
<?xml version="1.0" encoding="UTF-8" ?>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="ja" lang="ja">
  <head>
    <title>Twitter</title>
  </head>
  <body>
    <div style="background-color:#9ae4e8;padding:3px;margin-bottom:1em">
      <a href="http://twitter.com/home"><img src="http://twitter.com/images/mobile.gif" alt="Twitter"/></a>
    </div>
    <div style="float:left; margin: 0 1em 0 1em;">
      <img src="[% user.profile_image_url %]" />
    </div>
    <div style="float:left;">
      <span style="font-weight:bold;">[% user.screen_name | html %] ([% user.name | html %])</span><br />
      <a href="http://twitter.com/[% user.screen_name | html %]/status/[% id %]" style="color:#aaaaaa">Tweet</a> <span style="color:#aaaaaa;margin-left:0.5em;">from [% source %]</span>
    </div>
    <div style="clear:both;padding:0.5em;">
      <p>[% text | html %]</p>
    </div>
    <div style="color:#ffffff;background-color:#9ae4e8;padding:3px;text-align:center;font-size:80%">
      <a href="http://github.com/kentaro/atok-plugin-twitter/tree/master" style="color:#ffffff">ATOK::Plugin::Twitter</a> / <a href="http://twitter.com/kentaro" style="color:#ffffff">@kentaro</a>
    </div>
  </body>
</html>
EOS
}

package ATOK::Plugin::Twitter::User;
use base qw(Class::Accessor::Lvalue::Fast);
__PACKAGE__->mk_accessors(qw(
    name
    screen_name
));

1;

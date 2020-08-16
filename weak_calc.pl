#!/usr/bin/perl
use utf8;
use strict;
use warnings;

use LINE::Bot::API;
use LINE::Bot::API::Builder::SendMessage;
use LINE::Bot::API::Builder::TemplateMessage;
use Mojolicious::Lite;
use Encode;
use JSON;

my $CHANNEL_ACCCESS_TOKEN = "";
my $CHANNEL_SECRET = "";

my $DOUBLE_DATASET = &openJson(app->home . "/data/double.json");
my $HALF_DATASET   = &openJson(app->home . "/data/half.json");
my $ZERO_DATASET   = &openJson(app->home . "/data/zero.json");

my $POKE_GET1_7_DATASET = &openJson(app->home . "/data/pokemon_data.json");
my $POKE_GEN8_DATASET = &openJson(app->home . "/data/gen8-jp.json");
my @POKE_DATASET = (@$POKE_GET1_7_DATASET, @$POKE_GEN8_DATASET);

# API認証情報
my $bot = LINE::Bot::API->new(
    channel_secret       => $CHANNEL_SECRET,
    channel_access_token => $CHANNEL_ACCCESS_TOKEN,
);

app->config(
    hypnotoad => {
        listen  => ['http://*:8096'],
        workers => 1,
    },
);

my $log = app->log;

## JSONの読み込み
sub openJson {
    my $filename = shift;
    open my $fh, '<', $filename
        or die "Can't open file \"$filename\": $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    $content = Encode::decode( 'utf-8', $content );
    $content = Encode::encode( 'utf-8', $content );
    my $data = decode_json($content);
    return $data;
}

# JSONからLINEに投稿されたタイプに合致する値を取得
sub getType {
    my $text    = shift;
    my $dataset = shift;
    for my $type ( @{ $dataset->{types} } ) {
        if ( $type->{$text} ) {
            return $type->{$text};
        }
    }
    my $empty = [];
    return $empty;
}

# 倍率計算
sub calcMagnification {
    my $e             = shift;
    my $dataset       = shift;
    my $magnification = shift;
    my $type          = shift;
    my $temp          = &getType( $e, $dataset );
    for my $name (@$temp) {
        $type->{$name} = exists( $type->{$name} ) ? $type->{$name} * $magnification : $magnification;
    }
    return $type;
}

# Botが投稿するメッセージの組み立て
sub buildPostMessage {
    my $prefix = shift;
    my $text   = shift;
    my $key    = shift;
    unless ($text) {
        $text = $prefix;
    }
    $text = $text . $key . "\n";
}

# 弱点探索
post '/weakbot/callback' => sub {
    my $self = shift;

    my $source = $self->req->body;

    ## シグネチャチェック
    unless ($bot->validate_signature(
            $source, $self->req->headers->header('X-Line-Signature')
        )
        )
    {
        return $self->render(
            json => { 'status' => "failed to validate signature" } );
    }

    # 投稿されたのがテキストかどうかを確認
    my $events = $bot->parse_events_from_json($source);
    my $event  = ${$events}[0];
    unless ( $event->is_message_event && $event->is_text_message ) {
        return $self->render( json => { 'status' => "not text event" } );
    }

    # token取得
    my $reply_token = $event->reply_token;

    # text取得
    my $reply_text = $event->text;
    $reply_text =~ s/\r//g;
    $reply_text =~ s/\n/ /g;

    unless ($reply_text) {
        return $self->render( json => { 'status' => "empty text." } );
    }

    my $flag = 0;
    my @req_types;
    my @abilities;
    my $type_text = "";
    my $abilities_text = "";

    for my $poke (@POKE_DATASET) { # ポケモンのタイプ・とくせいを検索する
        if ($reply_text eq $poke->{name}) {
            @req_types = @{$poke->{types}};
            @abilities = @{$poke->{abilities}};
            if ($poke->{hiddenAbilities}) {
                push(@abilities, @{$poke->{hiddenAbilities}});
            }
            my %tmp;
            @abilities = grep { $tmp{$_}++ < 1; } (@abilities);
            $type_text = "👾 ";
            $abilities_text = "😐 ";

            $flag = 1;
            last;
        }
    }
    unless ($flag) { # 投稿されたテキストをリスト化する
        @req_types = split( /[ 　]+/, $reply_text );
    }

    # 倍率計算, タイプ出力
    my $type = {};
    for my $req_type (@req_types) {
        if ($flag) {
            $type_text = $type_text . $req_type . " ";
        }
        $type = &calcMagnification( $req_type, $DOUBLE_DATASET, 2,   $type );
        $type = &calcMagnification( $req_type, $HALF_DATASET,   0.5, $type );
        $type = &calcMagnification( $req_type, $ZERO_DATASET,   0,   $type );
    }

    # とくせい出力
    for my $ability (@abilities) {
        $abilities_text = $abilities_text . $ability . " ";
    }
    if ($flag) {
        $type_text = $type_text . "\n" ."$abilities_text" . "\n";
    }

    # 投稿するメッセージの組み立て
    my $message4 = "";
    my $message2 = "";
    my $messageh = "";
    my $messagen = "";
    my $messagez = "";

    for my $key ( sort { $type->{$b} <=> $type->{$a} } keys %$type ) {
        if ( $type->{$key} == 4 ) {
            $message4
                = &buildPostMessage( "⬆️⬆️ x4 ------\n", $message4, $key );
        }
        elsif ( $type->{$key} == 2 ) {
            $message2
                = &buildPostMessage( "⬆️ x2 ---------\n", $message2, $key );
        }
        elsif ( $type->{$key} == 0.5 ) {
            $messageh
                = &buildPostMessage( "⬇️ x0.5 -------\n", $messageh, $key );
        }
        elsif ( $type->{$key} == 0.25 ) {
            $messagen
                = &buildPostMessage( "⬇️⬇️ x0.25 ---\n", $messagen, $key );
        }
        elsif ( $type->{$key} == 0 ) {
            $messagez
                = &buildPostMessage( "🆖 x0 ---------\n", $messagez, $key );
        }
    }

    my $posttext = $type_text . $message4 . $message2 . $messageh . $messagen . $messagez;
    chomp($posttext);

    # メッセージの投稿
    my $messages = LINE::Bot::API::Builder::SendMessage->new;
    $messages->add_text( text => $posttext );
    $bot->reply_message( $reply_token, $messages->build );

    return $self->render( json => { 'status' => "OK" } );

} => 'callback';

app->start;

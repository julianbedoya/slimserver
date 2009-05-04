package Slim::Plugin::iTunes::Settings;

# SqueezeCenter Copyright 2001-2007 Logitech.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

use strict;
use base qw(Slim::Web::Settings);

use Slim::Utils::Log;
use Slim::Utils::Misc;
use Slim::Utils::Strings qw(string);
use Slim::Utils::Prefs;
use Slim::Plugin::iTunes::Plugin;

my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.itunes',
	'defaultLevel' => 'ERROR',
});

my $prefs = preferences('plugin.itunes');

$prefs->migrate(1, sub {
	$prefs->set('itunes',          Slim::Utils::Prefs::OldPrefs->get('itunes'));
	$prefs->set('scan_interval',   Slim::Utils::Prefs::OldPrefs->get('itunesscaninterval')   || 3600      );
	$prefs->set('ignore_disabled', Slim::Utils::Prefs::OldPrefs->get('ignoredisableditunestracks') || 0   );
	$prefs->set('xml_file',        Slim::Utils::Prefs::OldPrefs->get('itunes_library_xml_path')           );
	$prefs->set('music_path',      Slim::Utils::Prefs::OldPrefs->get('itunes_library_music_path')         );
	$prefs->set('playlist_prefix', Slim::Utils::Prefs::OldPrefs->get('iTunesplaylistprefix') || '');
	$prefs->set('playlist_suffix', Slim::Utils::Prefs::OldPrefs->get('iTunesplaylistsuffix') || ''        );
	1;
});

$prefs->setValidate({ 'validator' => 'intlimit', 'low' => 0 }, 'scan_interval');
$prefs->setValidate('file', 'xml_file');
$prefs->setValidate('dir', 'music_path');

$prefs->setChange(
	sub {
		my $value = $_[1];
		
		Slim::Music::Import->useImporter('Slim::Plugin::iTunes::Plugin', $value);

		for my $c (Slim::Player::Client::clients()) {
			Slim::Buttons::Home::updateMenu($c);
		}
		
		# Default TPE2 as Album Artist pref if using iTunes
		if ( $value ) {
			preferences('server')->set( useTPE2AsAlbumArtist => 1 );
		}
	},
'itunes');

$prefs->setChange(
	sub {
		Slim::Utils::Timers::killTimers(undef, \&Slim::Plugin::iTunes::Plugin::checker);

		my $interval = int( $prefs->get('scan_interval') );

		if ($interval) {
			
			$log->info("re-setting checker for $interval seconds from now.");
	
			Slim::Utils::Timers::setTimer(undef, Time::HiRes::time() + $interval, \&Slim::Plugin::iTunes::Plugin::checker);
		}
		
		else {
			
			$log->info("disabling checker - interval set to '$interval'");
		}
	},
'scan_interval');

$prefs->setChange(
	sub {
		Slim::Control::Request::executeRequest(undef, ['rescan']);
	},
'ignore_playlists');

sub name {
	return Slim::Web::HTTP::protectName('ITUNES');
}

sub page {
	return Slim::Web::HTTP::protectURI('plugins/iTunes/settings/itunes.html');
}

sub prefs {
	return ($prefs, qw(itunes scan_interval ignore_disabled xml_file music_path playlist_prefix playlist_suffix ignore_playlists));
}

sub handler {
	my ($class, $client, $params) = @_;

	# Cleanup the checkbox
	$params->{'pref_itunes'} = defined $params->{'pref_itunes'} ? 1 : 0;

	return $class->SUPER::handler($client, $params);
}

1;

__END__

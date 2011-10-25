# Package: Derbeth::Web.pm
#   narzedzia do sieci
#
# Uwagi:
#   w module znajduje sie cache'owanie stron
package Derbeth::Web;
@EXPORT = ('pobierz_strone','ustaw_online');

use LWP;
use HTTP::Daemon;
use HTTP::Status;
use HTTP::Response;
use HTTP::Request;
use HTTP::Request::Common;
use HTTP::Status;

#use encoding 'cp1250'; # - wywoluje bledy
use Digest::MD5 'md5_hex';

###################################################
# Section: Ustawienia
###################################################

# Bool: $online
#   ustala, czy ma pobierac strone z sieci czy z pliku in.txt
my $online = 1;

# Bool: $cache_on
#   ustala, czy maja byc cache'owane pobierane strony
$cache_on = 0;

$max_plikow_w_cache = 100;

# File: $input_file
#   plik uzywany jako wejscie
my $input_file = 'in.txt';

my $cache_dir = 'Derbeth/cache/';

my $USER_AGENT = "DerbethBot/beta (Windows XP) Opera rulez";

# Bool: $DOWNLOAD_METHOD
#   get/post
my $DOWNLOAD_METHOD = "get";

#####################################################
# Section: Funkcje
#####################################################

sub set {
	my($key,$val) = @_;
	if( $key eq 'USER_AGENT' ) { $USER_AGENT = $val; }
	if( $key eq 'DOWNLOAD_METHOD' ) { $DOWNLOAD_METHOD = $val; }
}

sub skrot_adresu {
   my $adres = shift @_;
   #print "[a:$adres]";
   #utf8::decode $adres;
   return md5_hex($adres);
   
}

sub czy_cacheowac {
   if( !$cache_on ) { return 0; }
   my $kat;
   opendir($kat,$cache_dir) or die("nie otwarto katalogu $cache_dir");
   my @pliki = readdir $kat or die("nie katalog");
   return( $#pliki < $max_plikow_w_cache );
}

# Function: sciagnij_strone
#   sciaga strone z internetu (funkcja wewnetrzna)
sub strona_z_sieci {
   my $adres = shift @_;
   my $ua = LWP::UserAgent->new;
   $ua->agent($USER_AGENT);
   my $response = ( $DOWNLOAD_METHOD eq 'get' ) ? $ua->get($adres) : $ua->post($adres);
   if( ! $response->is_success ) {
   	my $err_msg = 'nieznany blad';
   	if( $response->is_error ) {
   		$err_msg = status_message( $response->code );
   	}
		print "nie udalo sie pobrac strony $adres. komunikat: '$err_msg'\n";
   	return '';
   }
   
   my $text = $response->content;
   return $text;
}

sub strona_z_pliku {
   my $plik = shift @_;
   #print "tryb offline\n";
   my $text = '';
   open(FILE,$plik) or die "nie udalo sie otworzyc strony z pliku $plik";
   my $c = <FILE>;
   while($c) { $text .= $c; $c=<FILE>; }
   return $text;
}

sub strona_do_pliku {
   my $tekst = \shift @_;
   my $plik = shift @_;
   
   open(PLIK,'>',$plik) or die "nie udalo sie zapisac strony do pliku $plik";
   print PLIK $$tekst;
}

#
# Function: pobierz_strone
#   pobiera strone z internetu lub serwuje ja z dysku
#
# Parametry:
#   $adres - adres URL
#
# Zwracana warto?
#   kod HTML strony
#
# Wymagania:
#   zmienna globalna <$online>
sub pobierz_strone {
   my $adres = shift @_;
   if( czy_cacheowac ) {
      $nazwa_pliku = $cache_dir.skrot_adresu($adres);
      if( -e $nazwa_pliku ) {
         #print "czytam cache\n"; #DEBUG
         return strona_z_pliku($nazwa_pliku);
      } else {
         my $tekst = strona_z_sieci($adres);
         #print "pisze cache\n"; #DEBUG
         strona_do_pliku($tekst, $nazwa_pliku);
         return $tekst;
      }
   }
   if( $online ) {
      return strona_z_sieci($adres);
   } else {
      return strona_z_pliku($input_file);
   }
}


1;

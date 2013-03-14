#
# Package: Derbeth::Wikipedia.pm
#   modu z funkcjami dla Wikipedii
#

package Derbeth::Wikipedia;
use Derbeth::Web;
@EXPORT = ('znajdz_adres');

# Function: znajdz_adres
#   przeksztaca link Wikipedii na adres URL
#
# Parametry:
#   $strona - link w wikikodzie np. [[koo]] albo [[b:de:C-Programmirung:libc]]
#
# Zwracana wartosc:
#   pusta tablica - gdy link jest nieprawidowy
#   (adres URL,nazwa_strony) - (http://de.wikibooks.org/wiki/C-Programmirung:libc,C-Programmirung:libc)
#
# Zmienne globalne:
#   $strona
#   $domena
sub znajdz_adres {

   my $strona = shift @_;

   #usuwamy [[ i ]]
   $strona =~ /^\s*\[\[([^]]*)]]\s*$/ or return ();
   $strona = $1;

   ## obsuga rodzaju projektu

   {
      # Projekt:
      #   0 - wikipedia
      #   1 - wikibooks
      #   2 - wikinews
      #   3 - wikisource
      #   4 - wiktionary
      #   5 - commons
      #   6 - meta
      $projekt = 0;

      $strona =~ /^(\w+):/;

      my $kasuj_prefiks = 0;

      SWITCH1: {
         if( $1 eq 'w' ) { $projekt = 0; $kasuj_prefiks = 1; last SWITCH1; }
         if( $1 eq 'b' ) { $projekt = 1; $kasuj_prefiks = 1; last SWITCH1; }
         if( $1 eq 'n' ) { $projekt = 2; $kasuj_prefiks = 1; last SWITCH1; }
         if( $1 eq 's' ) { $projekt = 3; $kasuj_prefiks = 1; last SWITCH1; }
         if( $1 eq 'd' || $1 eq 'wikt' ) { $projekt = 4; $kasuj_prefiks = 1; last SWITCH1; }
         if( $1 eq 'commons' ) { $projekt = 5; $kasuj_prefiks = 1; last SWITCH1; }
         if( $1 eq 'm' || $1 eq 'meta' ) { $projekt = 6; $kasuj_prefiks = 1; last SWITCH1; }
      }

      if( $kasuj_prefiks ) {
         $strona =~ s/^(\w+:)//;
      }
   }

   ## obsuga j?kw

   {
      # J?ki
      #    0 - pl
      #    1 - en
      #    2 - de
      $jezyk = 0;

      $strona =~ /^(\w+):/;

      my $kasuj_prefiks = 0;

      SWITCH2: {
        if( $1 eq 'pl' ) { $jezyk = 0; $kasuj_prefiks = 1; last SWITCH2; }
        if( $1 eq 'en' ) { $jezyk = 1; $kasuj_prefiks = 1; last SWITCH2; }
        if( $1 eq 'de' ) { $jezyk = 2; $kasuj_prefiks = 1; last SWITCH2; }
      }

      if( $kasuj_prefiks ) {
         $strona  =~ s/^(\w+:)//;
      }
   }

   ## konstruujemy adres

   {
      my $a_jezyk;
      SWITCH3: {
         if( $jezyk == 0 ) { $a_jezyk = 'pl'; last SWITCH3; }
         if( $jezyk == 1 ) { $a_jezyk = 'en'; last SWITCH3; }
         if( $jezyk == 2 ) { $a_jezyk = 'de'; last SWITCH3; }
         die "zla wartosc a_jezyk: $a_jezyk";
      }

      my $a_projekt;
      SWITCH4: {
         if( $projekt == 0 ) { $a_projekt = 'wikipedia'; last SWITCH4; }
         if( $projekt == 1 ) { $a_projekt = 'wikibooks'; last SWITCH4; }
         if( $projekt == 2 ) { $a_projekt = 'wikinews'; last SWITCH4; }
         if( $projekt == 3 ) { $a_projekt = 'wikisource'; last SWITCH4; }
         if( $projekt == 4 ) { $a_projekt = 'wiktionary'; last SWITCH4; }
         if( $projekt == 5 ) { $a_jezyk = 'commons'; $a_projekt = 'wikimedia'; last SWITCH4; }
         if( $projekt == 6 ) { $a_jezyk = 'meta'; $a_projekt = 'wikimedia'; last SWITCH4; }
         die "zla wartosc a_projekt: $a_projekt";
      }

      $domena = "$a_jezyk.$a_projekt.org";
   }

   return ("http://$domena/wiki/$strona",$strona,$domena);
}

# Function: strona_istnieje
#   sprawdza, czy strona istnieje na Wikipedii, czy jest to pusty link
#
# Parametry:
#   $text - tekst strony (przekazywany przez referencj?
sub strona_istnieje {
   my $text = \shift @_;
   #return( index($$text, "Search/$nazwa_strony") == -1 );
   return( index($$text, ':Log/delete') == -1 && index($$text, 'Wikibooks nie posiada') == -1
      && index($$text, 'Wikipedii nie ma') == -1 && index($$text, 'Nie ma jeszcze artyk') == -1
		&& index($$text, 'Clear the cache') == -1 && index($$text, 'Access Denied') == -1)
		&& index($$text, 'Obecnie nie istnieje tekst o podanym tytule') == -1;
}

sub jest_redirectem {
   my $text = \shift @_;
   #if( $$text eq '' ) { die; }
   #print $$text;
   return( index($$text, '#REDIRECT') != -1 || index($$text, 'redirectText') != -1 );
}

# Function: wydziel_zawartosc
#   zwraca tylko tekst artykulu
sub wydziel_zawartosc {
   my $text = \shift @_;
   my $poczatek = index($$text, 'start content');
   my $koniec = index($$text, 'printfooter');
   if( $poczatek == -1 || $koniec == -1 ) {return $$text; }

   return substr($$text, $poczatek, $koniec-$poczatek);
}

# Function: wydziel_zawartosc_odkreski
#   zwraca tylko tekst artykulu
sub wydziel_zawartosc_odkreski {
   my $text = \shift @_;
   my $poczatek = index($$text, '<hr />');
   my $koniec = index($$text, 'printfooter');
   if( $poczatek == -1 || $koniec == -1 ) { return $$text; }

   return substr($$text, $poczatek, $koniec-$poczatek);
}

#
sub pobierz_zawartosc_strony {
   my $url = shift @_;

   return wydziel_zawartosc( Derbeth::Web::get_page($url) );
}

sub pobierz_zawartosc_artykulu {
   my $artykul = shift @_;
   my @dane = Derbeth::Wikipedia::znajdz_adres($artykul);
   if( $#dane == -1 ) {
      print STDERR "zy link Wikipedii: '$artykul'\n";
      return '';
   }
   my ($url,) = @dane;
   return pobierz_zawartosc_strony($url);
}

1;

#!/usr/bin/env perl
	package Snippets2025;
	
	use strict;
	use warnings;
	use Sys::Hostname;
    use DBI;
	
	# Exporter allows you to export functions to the caller's namespace
	use Exporter 'import';
	
	# Define export tags
our %EXPORT_TAGS = ( 
           'all' => [qw(var_init log_message $VERSION search_url get_blocked)], 
           );
	our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
	our $VERSION     = '1.00';
	my $hostname_env = hostname() || 'unbekannt';
	my %pathinfo = (
										'lib' => "../lib",
										'script' => "./",
										'log' => "../log",
									);

    my $dbname = 'url.db';
    
	# Constructor for object-oriented usage
	sub new {
	    my ($class, %args) = @_;
	    my $self = {
               hostname    => $hostname_env,
               pathinfo    => \%pathinfo,
	    };

	    bless $self, $class;
	    $self->var_init;  # Pfade initialisieren
	    return $self;
	}
	
	sub var_init {
		
	  	if( $hostname_env eq "kdeneon" ){
			$pathinfo{'lib'} = "/home/franz/Perl/perl_proxy/lib";
			$pathinfo{'script'} = "/home/franz/Perl/perl_proxy/script";
			$pathinfo{'log'} = "/home/franz/Perl/perl_proxy/log";
		}
		elsif( $hostname_env eq "conti.abf24.net" ){
			$pathinfo{'lib'} = "/usr/share/perl_proxy/lib";
			$pathinfo{'script'} = "/usr/share/perl_proxy/script";
			$pathinfo{'log'} = "/usr/share/perl_proxy/log";
		}
		else {
                warn "Unbekannter Hostname: $hostname_env. Verwende Standardpfade.\n";
        }
		return;
	}

sub search_url {
	my $text = shift;

		# Beispiel: Suche in der Datenbank
		my $search_word = lc($text);
		my $db = $pathinfo{'script'} ."/".$dbname;
		 log_message("Search4Host: ".$search_word);
		# Verbindung zur SQLite-Datenbank herstellen
        my $dbh = DBI->connect("dbi:SQLite:dbname=$db", "", "", { RaiseError => 1 });		
        # INSERT INTO index_table (word, line_number)
		my $count = $dbh->selectrow_array("SELECT count(line_number) FROM index_table WHERE INSTR(word,'$search_word')>0 ");
        $dbh->disconnect;	
        log_message("COUNT: ".$count);
        return $count;
}
	
	sub log_message {
	    my ($message) = @_;
	    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
	    $year = $year+1900;
	    my $filedate = "$mday\_$mon\_$year";
	   
			open(my $log_fh, '>>', $pathinfo{log}."/".$filedate.'_proxy.log') or do {
				warn "Could not open log file: $!";
				return 0;  # Fehler
			};	    
	    print $log_fh "[$mday-$mon-$year $hour:$min] $message\n";
	    close($log_fh);
	    
	    return 1;
	}
	
	# Object method: Get the person's name
	sub get_blocked {
		my $file = $pathinfo{lib}."/blocked.html";
	    my $contents = do { local(@ARGV, $/) = $file; <> };
	    return $contents;
	}
	
	# Object method: Set the person's name
	sub set_name {
	    my ($self, $new_name) = @_;
	    $self->{name} = $new_name;
	    return $self->{name};
	}
	
	# Object method: Get the person's age
	sub get_age {
	    my ($self) = @_;
	    return $self->{age};
	}
	
	# Object method: Increment the person's age by 1
	sub increment_age {
	    my ($self) = @_;
	    $self->{age}++;
	    return $self->{age};
	}
	

	
	1;  # End of module (must return true)
	

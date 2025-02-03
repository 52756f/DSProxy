#!/usr/bin/env perl

	use strict;
	use warnings;
    use DBI;
	
	my $filter_file = 'filter_urls.txt';
    my $dbname = 'url.db';
    
init_db();
exit(0);

	sub init_db {

		# Verbindung zur SQLite-Datenbank herstellen
        my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", "", "", { RaiseError => 1 });
        $dbh->do("DELETE FROM index_table;");
        $dbh->do("VACUUM;");
    
			# Datei einlesen und indexieren
			open(my $fh, '<', $filter_file) or die "Kann Datei $filter_file nicht öffnen: $!";
			my $line_number = 0;

			while (my $line = <$fh>) {
				$line_number++;
				$dbh->do("INSERT INTO index_table (word, line_number) VALUES (?, ?)", undef, lc($line), $line_number);
			}

			close($fh);
			$dbh->disconnect;
}

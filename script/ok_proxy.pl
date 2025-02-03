#!/usr/bin/perl -I/home/franz/Perl/perl_proxy/lib

    use strict; use warnings;
    use Snippets2025 qw(:all);
    use Socket;
    use Fcntl;
    use POSIX ":sys_wait_h";  # Für waitpid und WNOHANG
    use POSIX qw(strftime);
    use IO::Socket::IP;
    use IO::Socket::SSL;
    use IO::Select;
    use MIME::Base64;
    use Data::Dumper;
    use feature 'say';
    use App::Daemon qw( daemonize );
    system("clear");
    $SIG{CHLD} = 'IGNORE'; # im parent
         
    my $info = Snippets2025->new();
    my $app_path = $info->{pathinfo}->{script};
    
    say "PATH using: ".$info->{pathinfo}->{script};
    say "PATH using: ".$info->{pathinfo}->{lib};
    say "PATH using: ".$info->{pathinfo}->{log};
    say "Hostname:".$info->{hostname};
     
    $App::Daemon::pidfile = $info->{pathinfo}->{script}."/ok_proxy.pid";  
    $App::Daemon::logfile = $info->{pathinfo}->{log}."/".strftime("%Y-%m-%d", localtime)."_daemon.log";
    daemonize();
    
    # start application
    #$ app start
      # stop application
    #$ app stop
      # start app in foreground (for testing)
    #$ app -X
      # show if app is currently running
    #$ app status
    
    select STDERR; $| = 1;  # make unbuffered
    select STDOUT; $| = 1;  # make unbuffered
    
    # Proxy-Konfiguration
    my $proxy_host = '0.0.0.0';  # Auf allen Interfaces lauschen
    #my $proxy_host = '2a02:c206:2133:8664::1'; 
    my $proxy_port = 5555;       # Port, auf dem der Proxy lauscht
    my $myhostname = "localhost";
    my $timeout = 10;  # Sekunden
    my $valid_credentials = 'franz:5$_almless';
    
    my $server_cert = $app_path.'/server.crt';
    my $server_key  = $app_path.'/server.key';
    my $client_cert   = $app_path.'/client.crt';  # Trust the client's self-signed certificate
    
    # Client configuration
           $client_cert  = $app_path.'/client.crt';
    my $client_key   = $app_path.'/client.key';
           $server_cert = $app_path.'/server.crt';  # Trust the server's self-signed certificate
    
 
    # Socket erstellen, um auf eingehende Verbindungen zu warten
    my $proxy_socket = IO::Socket::IP->new(
        Domain    => PF_INET6,
        LocalHost => $proxy_host,
        LocalPort => $proxy_port,
        Proto     => 'tcp',
        Reuse     => 1,
        Listen    => SOMAXCONN,
        SSL_cert_file => $server_cert,
        SSL_key_file  => $server_key,
        SSL_verify_mode => 0x03,  # Require client certificate (SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT)
        SSL_ca_file   => $client_cert,  # Explicitly trust the client's self-signed certificate
        SSL_verify_callback => sub {
            my ($is_verified, $ssl_obj, $cert_error) = @_;
            if ($is_verified) {
                log_message ("Client certificate verified successfully.");
            } else {
                log_message ("Client certificate verification failed:". $cert_error);
            }
            return $is_verified;
        },    
    ) or die "Could not create socket: $!";
    
    say "Proxy server listen on $proxy_host:$proxy_port";
    log_message("Proxy server listen on $proxy_host:$proxy_port");
    
    # Hauptschleife des Proxys
    while (my $client_socket = $proxy_socket->accept()) {
        $client_socket->autoflush(1);
        my $client_address = $client_socket->peerhost();
        my $client_port = $client_socket->peerport();
        print "New connection from $client_address:$client_port\n";
        log_message("New connection from $client_address:$client_port");     
               
        # Neue Verbindung in einem separaten Prozess behandeln
                         my $pid = fork();
						die "Unable to fork: $!." unless defined $pid;
						unless ( $pid ) {
									# Schließe den Server-Socket im Kindprozess
									$proxy_socket->close(); 
									handle_client($client_socket);
								exit 0;
						}
     } #end while         
    exit(0);
    #----------------------------------------------------------
    sub handle_client {
        my ($client_socket,$proxy_socket) = @_;
        $SIG{CHLD} = 'DEFAULT';
        # Lese die Anfrage vom Client
        my $request = '';
        my $credentials = "";
    
        while (<$client_socket>) {
            $request .= $_;
            last if ($request =~ /\r\n\r\n$/);
        }
    
        if ($request =~ /Proxy-Authorization:\s*Basic\s+(\S+)/) {
           $credentials = decode_base64($1);
                if ($credentials ne $valid_credentials) {
                    print $client_socket "HTTP/1.1 407 Proxy Authentication Required\r\n";
                    print $client_socket "Proxy-Authenticate: Basic realm=\"Proxy\"\r\n\r\n";
                    $client_socket->close();
                    log_message("Login failed: ".$credentials);
                    return;
                }
        } else {
            print $client_socket "HTTP/1.1 407 Proxy Authentication Required\r\n";
            print $client_socket "Proxy-Authenticate: Basic realm=\"Proxy\"\r\n\r\n";
            $client_socket->close();
            log_message("Login Ok: ".$credentials);
            return;
        }
    
        # Extrahiere die Ziel-URL aus der Anfrage
        if ($request =~ /^(CONNECT|GET|POST|HEAD|PUT|DELETE|OPTIONS|TRACE) (\S+) HTTP\/\d\.\d/) {
            my $method = $1;
            my $url = $2;
            log_message( "Target: $url" );
    
            if ($method eq 'CONNECT') {
                # HTTPS-Verbindung
                handle_https($client_socket, $url);
            } else {
                # HTTP-Verbindung
                handle_http($client_socket, $request);
            }
        } else {
            print "Invalid request\n";
        }
    
        $client_socket->close();
        return;
    
    }
    
    #----------
    sub handle_https {
        my ($client_socket, $url) = @_;
    
        # Extrahiere Host und Port aus der URL
        my ($host, $port) = split(':', $url);
        $port ||= 443;
        print "--- Extracted Hostname: $host with Port: $port\n";
        
        if( search_url($host) > 0 ){  
			$client_socket->syswrite(  "HTTP/1.1 404 Not Found\r\n" );
			$client_socket->syswrite(  "Content-Type: text/html; charset=UTF-8\r\n\r\n" );
			log_message($host." BLOCKED");
			$client_socket->syswrite( get_blocked() );
			$client_socket->close();
			return;
			}
    
        my $remote_socket = IO::Socket::SSL->new(
            PeerHost => $host,
            PeerPort => $port,
            SSL_verify_mode => 0,
            SSL_startHandshake => 0,
            SSL_hostname => $myhostname,
            SSL_verify_mode => 0x01,  # Verify server certificate (SSL_VERIFY_PEER)
            SSL_ca_file    => $server_cert,  # Explicitly trust the server's self-signed certificate
            SSL_cert_file  => $client_cert,
            SSL_key_file   => $client_key,        
        ) or warn "error=$!, ssl_error=$SSL_ERROR" . "Could not connect to $host:$port: $!";      
    
        # Sende eine "200 Connection Established" Antwort an den Client
        if( $remote_socket ){
            $remote_socket->blocking(0);
            print $client_socket "HTTP/1.1 200 Connection Established\r\n\r\n";
         }else{
             $client_socket->close();
            return;
         }
    
        # Weiterleitung der Daten zwischen Client und Server
        my $select = IO::Select->new();
        $select->add($client_socket, $remote_socket);
    
        while (1) {
            my @ready = $select->can_read($timeout);
            last if ($select->count() < 2);
            
            foreach my $socket (@ready) {
                my $data;
                my $bytes_read = $socket->sysread($data, 16384);
    
                if ( not( defined $bytes_read ) ){
                    $select->remove($socket);
                    $socket->close();
                    last if ($select->count() < 2);
                    next;
                }
    
                if ($bytes_read <= 0) {
                    $select->remove($socket);
                    $socket->close();
                    last if ($select->count() < 2);
                    next;
                }
    
                my $other_socket = ($socket == $client_socket) ? $remote_socket : $client_socket;
                $other_socket->syswrite($data);
            }
        }
        print "EXIT https Select loop\n";
        return;
    }
    #----------
    sub handle_http {
        my ($client_socket, $request) = @_;
        my $host = "";
        my $port = 80;
    
    # Hostname aus Header extrahieren inklusive möglicher Port (url:81)
    if ($request =~ /Host:\s*(\S+)/i) {
        $host = $1;
        ($host,$port) = split(/:/,$host) if( $host =~ /\d$/ );
        print "--- Extracted Hostname: $host with Port: $port\n";
    }
    
           if( search_url($host) > 0 ){  
			     $client_socket->syswrite(  "HTTP/1.1 404 Not Found\r\n" );
			     $client_socket->syswrite(  "Content-Type: text/html; charset=UTF-8\r\n\r\n" );
			    $client_socket->syswrite( get_blocked() );
			    $client_socket->close();
			    log_message($host." BLOCKED");
			    return;
			}    
    # Socket erstellen
    socket(my $sock, AF_INET, SOCK_STREAM, 0) or warn "Socket error: $!";
    # Non-Blocking-Modus aktivieren
    fcntl($sock, F_SETFL, O_NONBLOCK) or warn "fcntl error: $!";
    my $addr = inet_aton($host) or warn "Host not found";
    my $sockaddr = sockaddr_in($port, $addr);
     # Verbindung herstellen
    connect($sock, $sockaddr) or warn "Couldn't connect to $host:$port: $!\n";
    
    my $select = IO::Select->new($sock);
    
    # Warten, bis der Socket bereit ist
    if ($select->can_write(5)) {
        my $n = send($sock, $request, 0) or warn "Send error: $!";
        if(not length $n ){ 
            close($sock);
            close($client_socket);
            return;     
        }
    }
    
    while (1) {
        if ($select->can_read(5)) {
            my $buffer;
            my $bytes = sysread($sock, $buffer, 2048);
            last if not defined $bytes or $bytes == 0;
            print $client_socket $buffer;
    
        } else {
            last;
        }
    }
    
    close($sock);
    close($client_socket); 
    return;
    }
    
    
    

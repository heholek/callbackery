package CallBackery::User;

# $Id: User.pm 539 2013-12-09 22:28:11Z oetiker $

# sorted hashes
use Mojo::Base -base;
use Carp qw(croak confess);
use Scalar::Util qw(weaken);
use Mojo::Util qw(b64_decode b64_encode secure_compare);
use Mojo::JSON qw(encode_json decode_json);
use CallBackery::Exception qw(mkerror);
use Time::HiRes qw(gettimeofday);

=head1 NAME

CallBackery::User - tell me about the current user

=head1 SYNOPSIS

 use CallBackery::User;
 my $user = CallBackery::User->new($self->controller);

 $user->werk;
 $user->may('right'); # does the user have the given right
 $user->id;

=head1 DESCRIPTION

All the methods if L<Mojo::Base> as well as the following

=head2 $self->controller

the controller

=cut

has 'controller';

=head2 $self->userId

By default the userId is numeric and represents a user account. For system tasks, it gets set to alphabetic identifiers.
The following alphabetic identifiers do exist:

 __CONSOLE when running in the config console mode
 __CONFIG for backup and restore tasks

=cut

    


=head2 userId

return the user id if the session user is valid.

=cut 

has userId => sub {
    my $self = shift;
    my $cookieUserId = $self->cookieConf->{u};
    my $dbh = $self->db->dbh;
    if (my $userId = [$dbh->selectrow_array('SELECT user_id FROM user WHERE user_id = ?',{},$cookieUserId)]->[0]){
        return $userId;
    } 
    my $userCount = [$dbh->selectrow_array('SELECT count(user_id) FROM user')]->[0];
    return ($userCount == 0 ? '__ROOT' : '' );
};

=head2 $self->db

a handle to a L<CallBackery::Database> object.

=cut

has app => sub {
    my $app = shift->controller->app;
    return $app;
};

has log => sub {
    shift->app->log;
};

has db => sub {
    CallBackery::Database->new(app=>shift->app);    
};

=head2 $self->userInfo

returns a hash of information about the current user.

=cut

has userInfo => sub {
    my $self = shift;
    if ($self->userId eq '__ROOT'){
        return {user_id => '__ROOT'};
    }
    if ($self->userId eq '__SHELL'){
        return {user_id => '__SHELL'};
    }
    $self->db->fetchRow('user',{id=>$self->userId}) // {};
};


=head2 $self->sessionConf

Extracts the session config from the cookie from the X-Session-Cookie header or the xsc parameter.
If the xsc parameter is set, its timestamp must be no older than 2 seconds.

=cut

has headerSessionCookie => sub {
    my $self = shift;
    my $c = $self->controller;
    return $c->req->headers->header('X-Session-Cookie');
};

has paramSessionCookie => sub {
    my $self = shift;
    my $c = $self->controller;
    return $c->param('xsc');
};

has firstSecret => sub {
    shift->controller->app->secrets()->[0];
};

has cookieConf => sub {
    my $self = shift;
    my $headerCookie = $self->headerSessionCookie;
    my $paramCookie = $self->paramSessionCookie;

    my ($data,$check) = split /:/,($headerCookie || $paramCookie || ''),2;
    
    return {} if not ($data and $check);

    my $secret = $self->firstSecret;
    my $checkTest = Mojo::Util::hmac_sha1_sum($data, $secret);
    if (not secure_compare($check,$checkTest)){
        $self->log->debug(qq{Bad signed cookie possible hacking attempt.});
        return {};
    }

    my $conf = eval {
        local $SIG{__DIE__};
        decode_json(b64_decode($data))
    };
    if ($@){
        $self->log->debug("Invalid cookie structure in '$data': $@");
        return {};
    }

    if (ref $conf ne 'HASH'){
        $self->log->debug("Cookie structure not a hash");
        return {};
    }

    if (not $conf->{t}){
        $self->log->debug("Cookie timestamp is invalid");
        return {};
    }

    if ($paramCookie and gettimeofday() - $conf->{t} > 2.0){
        $self->log->debug(qq{Cookie is expired});
        die mkerror(38445,"cookie has expired");
    }
    return $conf;
};

=head2 $bool = $self->C<may>(right);

Check if the user has the right indicated.

=cut

sub may {
    my $self = shift;
    my $right = shift;
    # root has all the rights
    if ($self->userId eq '__ROOT'){
        return 1;
    }
    my $db = $self->db;
    my $rightId = $db->lookUp('right','key',$right);
    my $userId = $self->id;
    return ($db->matchData('userright',{user=>$self->userId,right=>$rightId}) ? 1 : 0);
}

=head2 makeSessionCookie()

Returns a timestamped, signed session cookie containing the current userId.

=cut

sub makeSessionCookie {
    my $self = shift;
    my $timeout = shift; 
    my $now = gettimeofday;
    my $conf = b64_encode(encode_json({
        u => $self->userId,
        t => $now,
    }));
    $conf =~ s/\s+//g;
    my $secret = $self->firstSecret;
    my $check = Mojo::Util::hmac_sha1_sum($conf, $secret);
    return $conf.':'.$check;
}



1;
__END__

=back

=head1 COPYRIGHT

Copyright (c) 2013 by OETIKER+PARTNER AG. All rights reserved.

=head1 AUTHOR

S<Tobi Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2010-06-12 to 1.0 initial
 2013-11-19 to 1.1 mojo port

=cut

# Emacs Configuration
#
# Local Variables:
# mode: cperl
# eval: (cperl-set-style "PerlStyle")
# mode: flyspell
# mode: flyspell-prog
# End:
#
# vi: sw=4 et
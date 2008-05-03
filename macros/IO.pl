################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: pg/macros/IO.pl,v 1.8 2007/10/25 17:11:59 sh002i Exp $
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

=head1 NAME

IO.pl - Input/optput macros that require access to the problem environment.

=head1 DESCRIPTION

See notes in L<WeBWorK::PG::Translator>.

=cut

# ^function _IO_init
sub _IO_init {}

# ^function _IO_export
sub _IO_export {
	return (
		'&send_mail_to',
		'&getCourseTempDirectory',
		'&surePathToTmpFile',
	);
}

=head1 MACROS

=head2 [DEPRECATED] send_mail_to

	send_mail_to($address, subject=>$subject, body=>$body)

Send an email message with the subject $subject and body $body to the address
$address. This used to be used by mail_answers_to in PGbasicmacros.pl, but it no
longer is. Don't use this, I tell yah!

=cut

# send_mail_to($user_address,'subject'=>$subject,'body'=>$body)
# ^function send_mail_to
# ^uses $envir{mailSmtpServer}
# ^uses $envir{mailSmtpSender}
# ^uses $REMOTE_HOST
# ^uses $REMOTE_ADDR
# ^uses Net::SMTP::new
sub send_mail_to {
	my $user_address = shift; # user must be an instructor
	my %options = @_;
	my $subject = '';
	my $msg_body = '';
	my @mail_to_allowed_list = ();
	my $out;
	
	my $server = $envir{mailSmtpServer};
	my $sender = $envir{mailSmtpSender};
	
	$subject = $options{'subject'} if defined $options{'subject'};
	$msg_body =$options{'body'} if defined $options{'body'};
	@mail_to_allowed_list = @{ $options{'ALLOW_MAIL_TO'} }
		if defined $options{'ALLOW_MAIL_TO'};
	
	# check whether user is an instructor
	my $mailing_allowed_flag = 0;
	
	while (@mail_to_allowed_list) {
		if ($user_address eq shift @mail_to_allowed_list ) {
			$mailing_allowed_flag = 1;
			last;
		}
	}
	
	if ($mailing_allowed_flag) {
		my  $email_msg = "To: $user_address\n"   
			. "X-Remote-Host: $REMOTE_HOST($REMOTE_ADDR)\n"
			. "Subject: $subject\n"
			. "\n"
			. $msg_body;
		my $smtp = Net::SMTP->new($server, Timeout=>10)
			or warn "Couldn't contact SMTP server.";
		$smtp->mail($sender);
		
		if ( $smtp->recipient($user_address)) {
			# this one's okay, keep going
			$smtp->data( $email_msg)
				or warn "Unknown problem sending message data to SMTP server.";
		} else {
			# we have a problem a problem with this address
			$smtp->reset;                     
			warn "SMTP server doesn't like this address: <$user_address>.";
		}
		$smtp->quit;	
	} else {
		die "There has been an error in creating this problem.\n"
			. "Please notify your instructor.\n\n"
			. "Mail is not permitted to address $user_address.\n"
			. "Permitted addresses are specified in global.conf or course.conf.";
		$out = 0;
	}
	
	return $out;
}

=head2 getCourseTempDirectory

	$path = getCourseTempDirectory()

Returns the path to the current course's temporary directory.

=cut

# ^function getCourseTempDirectory
# ^user $envir{tempDirectory}
sub getCourseTempDirectory {
	return $envir{tempDirectory};
}

=head2 surePathToTmpFile

	$path = surePathToTmpFile($path);

Creates all of the intermediate directories between the directory specified by
getCourseTempDirectory() and file specified in $path.

If $path begins with the path returned by getCourseTempDirectory(), then the
path is treated as absolute. Otherwise, the path is treated as relative the the
course temp directory.

=cut

# A very useful macro for making sure that all of the directories to a file have been constructed.

# ^function surePathToTmpFile
# ^uses getCourseTempDirectory
# ^uses createDirectory
sub surePathToTmpFile {
	# constructs intermediate directories if needed beginning at ${Global::htmlDirectory}tmp/
	# the input path must be either the full path, or the path relative to this tmp sub directory
	
	my $path = shift;
	my $delim = "/"; #&getDirDelim();
	my $tmpDirectory = getCourseTempDirectory();
	unless ( -e $tmpDirectory) {   # if by some unlucky chance the tmpDirectory hasn't been created, create it.
	    my $parentDirectory =  $tmpDirectory;
	    $parentDirectory =~s|/$||;  # remove a trailing /
	    $parentDirectory =~s|/\w*$||; # remove last node
	    my ($perms, $groupID) = (stat $parentDirectory)[2,5];
		createDirectory($tmpDirectory, $perms, $groupID)
				or warn "Failed to create directory at $path";
	
	}
	# use the permissions/group on the temp directory itself as a template
	my ($perms, $groupID) = (stat $tmpDirectory)[2,5];
	#warn "&urePathToTmpFile: perms=$perms groupID=$groupID\n";
	
	# if the path starts with $tmpDirectory (which is permitted but optional) remove this initial segment
	$path =~ s|^$tmpDirectory|| if $path =~ m|^$tmpDirectory|;
	#$path = convertPath($path);
	
	# find the nodes on the given path
        my @nodes = split("$delim",$path);
	
	# create new path
	$path = $tmpDirectory; #convertPath("$tmpDirectory");
	
	while (@nodes>1) {
		$path = $path . shift (@nodes) . "/"; #convertPath($path . shift (@nodes) . "/");
		unless (-e $path) {
			#system("mkdir $path");
			#createDirectory($path,$Global::tmp_directory_permission, $Global::numericalGroupID)
			createDirectory($path, $perms, $groupID)
				or warn "Failed to create directory at $path";
		}

	}
	
	$path = $path . shift(@nodes); #convertPath($path . shift(@nodes));
	#system(qq!echo "" > $path! );
	return $path;
}

1;

package threads;

use 5.008;
use strict;
use warnings;
use Config;

BEGIN {
    unless ($Config{useithreads}) {
	my @caller = caller(2);
        die <<EOF;
$caller[1] line $caller[2]:

This Perl hasn't been configured and built properly for the threads
module to work.  (The 'useithreads' configuration option hasn't been used.)

Having threads support requires all of Perl and all of the XS modules in
the Perl installation to be rebuilt, it is not just a question of adding
the threads module.  (In other words, threaded and non-threaded Perls
are binary incompatible.)

If you want to the use the threads module, please contact the people
who built your Perl.

Cannot continue, aborting.
EOF
    }
}

use overload
    '==' => \&equal,
    'fallback' => 1;

BEGIN {
    warn "Warning, threads::shared has already been loaded. ".
       "To enable shared variables for these modules 'use threads' ".
       "must be called before any of those modules are loaded\n"
               if($threads::shared::threads_shared);
}

our $VERSION = '1.18';


# Load the XS code
require XSLoader;
XSLoader::load('threads', $VERSION);


### Export ###

sub import
{
    my $class = shift;   # Not used

    # Exported subroutines
    my @EXPORT = qw(async);

    # Handle args
    while (my $sym = shift) {
        if ($sym =~ /all/) {
            push(@EXPORT, qw(yield));

        } else {
            push(@EXPORT, $sym);
        }
    }

    # Export subroutine names
    my $caller = caller();
    foreach my $sym (@EXPORT) {
        no strict 'refs';
        *{$caller.'::'.$sym} = \&{$sym};
    }
}


### Methods, etc. ###

# use "goto" trick to avoid pad problems from 5.8.1 (fixed in 5.8.2)
# should also be faster
sub async (&;@) { unshift @_,'threads'; goto &new }

$threads::threads = 1;

# 'new' is an alias for 'create'
*new = \&create;

1;

__END__

=head1 NAME

threads - Perl interpreter-based threads

=head1 VERSION

This document describes threads version 1.18

=head1 SYNOPSIS

    use threads ('yield');

    sub start_thread {
        my @args = @_;
        print "Thread started: @args\n";
    }
    my $thread = threads->create('start_thread', 'argument');
    $thread->join();

    threads->create(sub { print("I am a thread\n"); })->join();

    my $thread3 = async { foreach (@files) { ... } };
    $thread3->join();

    # Invoke thread in list context so it can return a list
    my ($thr) = threads->create(sub { return (qw/a b c/); });
    my @results = $thr->join();

    $thread->detach();

    $thread = threads->self();
    $thread = threads->object($tid);

    $tid = threads->tid();
    $tid = threads->self->tid();
    $tid = $thread->tid();

    threads->yield();
    yield();

    my @threads = threads->list();

    if ($thr1 == $thr2) {
        ...
    }

=head1 DESCRIPTION

Perl 5.6 introduced something called interpreter threads.  Interpreter
threads are different from "5005threads" (the thread model of Perl
5.005) by creating a new perl interpreter per thread and not sharing
any data or state between threads by default.

Prior to perl 5.8 this has only been available to people embedding
perl and for emulating fork() on windows.

The threads API is loosely based on the old Thread.pm API. It is very
important to note that variables are not shared between threads, all
variables are per default thread local.  To use shared variables one
must use threads::shared.

It is also important to note that you must enable threads by doing
C<use threads> as early as possible in the script itself and that it
is not possible to enable threading inside an C<eval "">, C<do>,
C<require>, or C<use>.  In particular, if you are intending to share
variables with threads::shared, you must C<use threads> before you
C<use threads::shared> and C<threads> will emit a warning if you do
it the other way around.

=over

=item $thr = threads->create(FUNCTION, ARGS)

This will create a new thread that will begin execution with the specified
entry point function, and give it the I<ARGS> list as parameters.  It will
return the corresponding threads object, or C<undef> if thread creation failed.

I<FUNCTION> may either be the name of a function, an anonymous subroutine, or
a code ref.

    my $thr = threads->create('func_name', ...);
        # or
    my $thr = threads->create(sub { ... }, ...);
        # or
    my $thr = threads->create(\&func, ...);

The thread may be created in I<list> context, or I<scalar> context as follows:

    # Create thread in list context
    my ($thr) = threads->create(...);

    # Create thread in scalar context
    my $thr = threads->create(...);

This has consequences for the C<-E<gt>join()> method describe below.

Although a thread may be created in I<void> context, to do so you must
I<chain> either the C<-E<gt>join()> or C<-E<gt>detach()> method to the
C<-E<gt>create()> call:

    threads->create(...)->join();

The C<-E<gt>new()> method is an alias for C<-E<gt>create()>.

=item $thr->join()

This will wait for the corresponding thread to complete its execution.  When
the thread finishes, C<-E<gt>join()> will return the return value(s) of the
entry point function.

The context (void, scalar or list) of the thread creation is also the
context for C<-E<gt>join()>.  This means that if you intend to return an array
from a thread, you must use C<my ($thr) = threads->create(...)>, and that
if you intend to return a scalar, you must use C<my $thr = ...>:

    # Create thread in list context
    my ($thr1) = threads->create(sub {
                                    my @results = qw(a b c);
                                    return (@results);
                                 };
    # Retrieve list results from thread
    my @res1 = $thr1->join();

    # Create thread in scalar context
    my $thr2 = threads->create(sub {
                                    my $result = 42;
                                    return ($result);
                                 };
    # Retrieve scalar result from thread
    my $res2 = $thr2->join();

If the program exits without all other threads having been either joined or
detached, then a warning will be issued. (A program exits either because one
of its threads explicitly calls L<exit()|perlfunc/"exit EXPR">, or in the case
of the main thread, reaches the end of the main program file.)

=item $thread->detach

Will make the thread unjoinable, and cause any eventual return value
to be discarded.

Calling C<-E<gt>join()> on a detached thread will cause an error to be thrown.

=item threads->detach()

Class method that allows a thread to detach itself.

=item threads->self

This will return the thread object for the current thread.

=item $thr->tid()

Returns the ID of the thread.  Thread IDs are unique integers with the main
thread in a program being 0, and incrementing by 1 for every thread created.

=item threads->tid()

Class method that allows a thread to obtain its own ID.

=item threads->object($tid)

This will return the I<threads> object for the I<active> thread associated
with the specified thread ID.  Returns C<undef> if there is no thread
associated with the TID, if the thread is joined or detached, if no TID is
specified or if the specified TID is undef.

=item threads->yield();

This is a suggestion to the OS to let this thread yield CPU time to other
threads.  What actually happens is highly dependent upon the underlying
thread implementation.

You may do C<use threads qw(yield)> then use just a bare C<yield> in your
code.

=item threads->list()

In a list context, returns a list of all non-joined, non-detached I<threads>
objects.  In a scalar context, returns a count of the same.

=item $thr1->equal($thr2)

Tests if two threads objects are the same thread or not.  This is overloaded
to the more natural form:

    if ($thr1 == $thr2) {
        print("Threads are the same\n");
    }

(Thread comparison is based on thread IDs.)

=item async BLOCK;

C<async> creates a thread to execute the block immediately following
it.  This block is treated as an anonymous sub, and so must have a
semi-colon after the closing brace. Like C<< threads->new >>, C<async>
returns a thread object.

=item $thr->_handle()

This I<private> method returns the memory location of the internal thread
structure associated with a threads object.  For Win32, this is the handle
returned by C<CreateThread>; for other platforms, it is the pointer returned
by C<pthread_create>.

This method is of no use for general Perl threads programming.  Its intent is
to provide other (XS-based) thread modules with the capability to access, and
possibly manipulate, the underlying thread structure associated with a Perl
thread.

=item threads->_handle()

Class method that allows a thread to obtain its own I<handle>.

=back

=head1 WARNINGS

=over 4

=item A thread exited while %d other threads were still running

A thread (not necessarily the main thread) exited while there were
still other threads running.  Usually it's a good idea to first collect
the return values of the created threads by joining them, and only then
exit from the main thread.

=back

=head1 ERRORS

=over 4

=item This Perl hasn't been configured and built properly for the threads...

The particular copy of Perl that you're trying to use was not built using the
C<useithreads> configuration option.

Having threads support requires all of Perl and all of the XS modules in the
Perl installation to be rebuilt; it is not just a question of adding the
L<threads> module (i.e., threaded and non-threaded Perls are binary
incompatible.)

=back

=head1 BUGS

=over

=item Parent-Child threads.

On some platforms it might not be possible to destroy "parent"
threads while there are still existing child "threads".

=item Creating threads inside BEGIN blocks

Creating threads inside BEGIN blocks (or during the compilation phase
in general) does not work.  (In Windows, trying to use fork() inside
BEGIN blocks is an equally losing proposition, since it has been
implemented in very much the same way as threads.)

=item PERL_OLD_SIGNALS are not threadsafe, will not be.

If your Perl has been built with PERL_OLD_SIGNALS (one has
to explicitly add that symbol to ccflags, see C<perl -V>),
signal handling is not threadsafe.

=item Returning closures from threads

Returning a closure from a thread does not work, usually crashing Perl in the
process.

=item Perl Bugs and the CPAN Version of L<threads>

Support for threads extents beyond the code in this module (i.e.,
F<threads.pm> and F<threads.xs>), and into the Perl iterpreter itself.  Older
versions of Perl contain bugs that may manifest themselves despite using the
latest version of L<threads> from CPAN.  There is no workaround for this other
than upgrading to the lastest version of Perl.

(Before you consider posting a bug report, please consult, and possibly post a
message to the discussion forum to see if what you've encountered is a known
problem.)

=back

=head1 REQUIREMENTS

Perl 5.8.0 or later

=head1 SEE ALSO

L<threads> Discussion Forum on CPAN:
L<http://www.cpanforum.com/dist/threads>

Annotated POD for L<threads>:
L<http://annocpan.org/~JDHEDDEN/threads-1.18/shared.pm>

L<threads::shared>, L<perlthrtut>

L<http://www.perl.com/pub/a/2002/06/11/threads.html> and
L<http://www.perl.com/pub/a/2002/09/04/threads.html>

Perl threads mailing list:
L<http://lists.cpan.org/showlist.cgi?name=iThreads>

=head1 AUTHOR

Artur Bergman E<lt>sky AT crucially DOT netE<gt>

threads is released under the same license as Perl.

CPAN version produced by Jerry D. Hedden <jdhedden AT cpan DOT org>

=head1 ACKNOWLEDGEMENTS

Richard Soderberg E<lt>perl AT crystalflame DOT netE<gt> -
Helping me out tons, trying to find reasons for races and other weird bugs!

Simon Cozens E<lt>simon AT brecon DOT co DOT ukE<gt> -
Being there to answer zillions of annoying questions

Rocco Caputo E<lt>troc AT netrus DOT netE<gt>

Vipul Ved Prakash E<lt>mail AT vipul DOT netE<gt> -
Helping with debugging

=cut

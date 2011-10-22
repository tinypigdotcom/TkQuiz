#!C:\perl\bin\perl.exe

# $Id: tkquiz.pl,v 1.1.1.1 2010-10-30 03:24:48 Dave Exp $
# tkquiz.pl - A simple quiz program
# Written by David M. Bradford except for fisher_yates_shuffle() which is from
# the Perl Cookbook, though I did re-name the variables for clarity.

# To Do:
#   * Expand regexes with whitespace (per flag x) and comment
#   * Executable
#   * Installation package

use strict;
use warnings;
use version; our $VERSION = qv('1.03');

use Carp;
use English qw( -no_match_vars );
use Tk;
use Tk::Dialog;

# "Constants" - using *my* for speed
my $BUTTON_WIDTH = 10;
my $ENTRY_WIDTH  = 70;
my $FONT         = 'Arial 10 normal';
my $FRAME_PADX   = 5;
my $FRAME_PADY   = 5;
my $PADX         = 5;
my $PADY         = 2;
my $ASTERISK     = q{*};
my $EMPTY_STRING = q{};

my $ABOUT_TEXT = <<"END_ABOUT_TEXT";
version $VERSION
Copyright (C) 2008 by David Bradford <davembradford\@gmail.com>

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself, either Perl version 5.8.8 or, at your option, any later version of Perl 5 you may have available.
END_ABOUT_TEXT

# Quiz variables
my $answer;
my $item;
my $question;
my @question_set;

my $correct_overall    = 0;
my $correct_this_run   = 0;
my $index              = 0;
my $questions_overall  = 0;
my $questions_this_run = 0;

my %regex = regular_expressions();

my %user_variables = (
    question_mark => q{?},
    plus          => q{+},
);

my $GUI = create_gui();

my $entry       = $GUI->{entry};
my $main_window = $GUI->{main_window};
my $text        = $GUI->{text};

my $entry_text;
my $status_label;
my $score_label;

MainLoop;

sub trim {
    my ($scalar_ref) = @_;

    for ( ${$scalar_ref} ) {
        s/$regex{leading_space}//xms;
        s/$regex{trailing_space}//xms;
        s/$regex{multiple_spaces}/ /gxms;
    }

    return;
}

sub display_help {
    system(1,"start tkquiz.html");

    return;
}

sub display_about {
    my $about_dialog = $main_window->Dialog(
        -text           => $ABOUT_TEXT,
        -title          => 'About',
        -font           => $FONT,
        -default_button => 'Ok',
        -buttons        => ['Ok']
    );
    $about_dialog->Show;

    return;
}

sub shuffle_questions {
    my ($set_aref) = @_;

    $index              = 0;
    $questions_this_run = 0;
    $correct_this_run   = 0;

    fisher_yates_shuffle($set_aref);

    return;
}

# fisher_yates_shuffle( \@array ) : generate a random permutation
# of @array in place
sub fisher_yates_shuffle {
    my ($array) = @_;

    return if ( scalar @{$array} <= 1 );

    my $current_element = @{$array};
    while ($current_element) {
        my $target_element = int rand $current_element;

        $current_element--;

        next if $current_element == $target_element;

        @{$array}[ $current_element,  $target_element ] =
          @{$array}[ $target_element, $current_element ];
    }

    return;
}

sub open_question_set {
    my $types = [ [ 'TkQuiz File', '.qs' ], [ 'All Files', $ASTERISK ], ];

    my $input_file_name = $main_window->getOpenFile( -filetypes => $types );

    return if ( not $input_file_name );
    {
        undef local $INPUT_RECORD_SEPARATOR;
        open my $infile, '<', $input_file_name
          or croak "Can't open $input_file_name: $OS_ERROR";
        my $file_contents = <$infile>;
        close $infile or croak;

        my @lines = split $regex{double_newline}, $file_contents;

        @question_set = ();
        for my $line (@lines) {
            chomp $line;
            next if ( is_blank($line) );

            if ( $line =~ $regex{variable_definition} ) {
                $user_variables{$1} = $2;
            }
            else {
                push @question_set, [ split $regex{question_mark}, $line ];
            }
        }
    }

    $questions_overall = 0;
    $correct_overall   = 0;

    $input_file_name = get_file_basename($input_file_name);

    $main_window->title("$input_file_name - TkQuiz");

    shuffle_questions( \@question_set );

    $entry_text   = $EMPTY_STRING;
    $status_label = $EMPTY_STRING;
    $score_label  = $EMPTY_STRING;

    ask_question();

    return;
}

sub display_score {
    return if ( $questions_overall <= 0 );

    my $percent_sign = q{%};

    $score_label =
"$correct_this_run out of $questions_this_run this run for an accuracy of "
      . int( $correct_this_run / $questions_this_run * 100 )
      . "$percent_sign\n"
      . "$correct_overall out of $questions_overall this set for an accuracy of "
      . int( $correct_overall / $questions_overall * 100 )
      . "$percent_sign";

    $main_window->update;

    return;
}

sub ask_question {
    $item     = $question_set[$index];
    $question = $item->[0];
    $answer   = $item->[1];

    interpolate_user_variables( \$question );

    # Question is multiple-choice
    if ( $answer =~ $regex{multiple_choice} ) {
        $question = "$question\n\n";
        my $answers_string = $1;
        my $i              = 0;

        my (@multi_choice_answers) =
          grep { m/$regex{non_space}/xms } split $regex{multiple_choice_line},
          "$answers_string\n";

        my $correct_answer = $multi_choice_answers[0];

        # permutes @array in place
        fisher_yates_shuffle( \@multi_choice_answers );

        my @all_letters = ( 'a' .. 'z' );
        for (@multi_choice_answers) {
            my $letter = $all_letters[ $i++ ];
            if ($correct_answer eq $_) {
                $answer = $letter;
            }
            $question .= "$letter)$_";
        }
    }

    display_question($question);

    return;
}

sub interpolate_user_variables {
    my ($input_scalar_ref) = @_;

    for ( ${$input_scalar_ref} ) {
        s/$regex{variable_interpolation}/$user_variables{$1}/egxms;
        s/$regex{variable_interp_braces}/$user_variables{$1}/egxms;
    }

    return;
}

sub display_question {
    my ($question) = @_;

    $text->configure( -state => 'normal' );
    $text->delete( '1.0', 'end' );
    $text->insert( 'end', "$question\n" );
    $text->update;
    $text->see( $text->index('insert') );
    $text->configure( -state => 'disabled' );
    $entry->focus();

    return;
}

sub process_answer {

    trim \$entry_text;

    return if ( $#question_set < 0 );

    my $answer_for_display;
    if ( not $answer ) {
        $answer = $item->[1];
    }
    $answer_for_display = $answer;

    my $answer_ok = $EMPTY_STRING;
    if ( not $entry_text ) {
        $answer_ok = display_status_message(
            title     => 'Spoken Guess',
            message   => "Answer: $answer_for_display\nWere you correct (y/n)?",
            yes_or_no => 1,
        );
    }

    trim \$answer;

    interpolate_user_variables( \$answer );

    $answer = quotemeta($answer);
    if ( $answer =~ $regex{capital_letter} ) {
        $answer = qr{$answer};
    }
    else {
        $answer = qr{$answer}i;
    }

    if ( $answer_ok eq 'Yes' or $entry_text =~ $answer ) {
        $status_label = 'Correct.';
        $correct_overall++;
        $correct_this_run++;
    }
    else {
        if ( not $answer_ok ) {
            display_status_message(
                title   => 'Incorrect',
                message => "Incorrect. $answer_for_display",
            );
        }
    }

    $entry_text = $EMPTY_STRING;

    $questions_overall++;
    $questions_this_run++;

    display_score();

    $index++;

    if ( $index > $#question_set ) {
        shuffle_questions( \@question_set );
        display_shuffling_message();
    }

    $answer = $EMPTY_STRING;

    ask_question();

    return;
}

sub display_status_message {
    my ( %args ) = @_;

    my $title     = $args{title};
    my $message   = $args{message};
    my $yes_or_no = $args{yes_or_no};

    my %extra_options;

    if($yes_or_no) {
        %extra_options = (
            -default_button => 'Yes',
            -buttons        => ['Yes','No'],
        );
    }

    my $d = $main_window->Dialog(
        -text  => $message,
        -title => $title,
        %extra_options,
    );
    $d->bind( '<y>' => sub { $d->Subwidget('B_Yes')->invoke } );
    $d->bind( '<n>' => sub { $d->Subwidget('B_No')->invoke } );

    my $dialog_answer = $d->Show;
    $status_label = $message;

    return $dialog_answer;
}

sub display_shuffling_message {
    my $w = $main_window->Toplevel();

    $w->geometry('120x50');
    $w->after( 2000, sub { $w->destroy } );
    $w->grab();
    $w->title('Shuffle');
    $w->Label(
        -text    => 'Shuffling...',
        -justify => 'left',
        -height  => 2,
        -font    => $FONT
      )->pack(
        -side   => 'top',
        -padx   => $PADX,
        -pady   => $PADY,
        -anchor => 'w'
      );
    $w->focus;
    $w->waitWindow();

    return;
}

sub create_gui {
    my %GUI;

    my $main_window = $GUI{main_window} = MainWindow->new();

    $main_window->title('TkQuiz');

    my $main_frame = $main_window->Frame(
        -relief      => 'ridge',
        -borderwidth => 2,
    );

    $main_window->geometry('600x600');

    $main_frame->pack(
        -side   => 'top',
        -anchor => 'n',
        -fill   => 'x',
    );

    my $frame_menu = $main_frame->Menubutton(
        -text      => 'File',
        -underline => 0,
        -font      => $FONT,
        -tearoff   => 0,
        -menuitems => [
            [
                'command'  => 'Open Question Set',
                -underline => 0,
                -font      => $FONT,
                -command   => \&open_question_set
            ],
            [
                'command'  => 'Exit',
                -underline => 1,
                -font      => $FONT,
                -command => sub { exit }
            ]
        ]
    )->pack( -side => 'left' );

    my $help_menu = $main_frame->Menubutton(
        -text      => 'Help',
        -underline => 0,
        -font      => $FONT,
        -tearoff   => 0,
        -menuitems => [
            [
                'command'  => 'Help',
                -underline => 0,
                -font      => $FONT,
                -command   => \&display_help
            ],
            [
                'command'  => 'About',
                -underline => 0,
                -font      => $FONT,
                -command   => \&display_about
            ]
        ]
    )->pack( -side => 'left' );

    my $text = $GUI{text} = $main_window->Scrolled(
        'Text',
        -height     => '10',
        -background => 'black',
        -foreground => 'green',
        -width      => '80',
        -scrollbars => 'e',
        -font       => $FONT
      )->pack(
        -side   => 'top',
        -expand => '1',
        -padx   => $PADX,
        -pady   => $PADY,
        -fill   => 'both'
      );

    my $frame = $main_window->Frame()->pack(
        -padx   => $FRAME_PADX,
        -pady   => $FRAME_PADY,
        -anchor => 'nw',
        -side   => 'top'
    );

    my $entry = $GUI{entry} = $frame->Entry(
        -width        => $ENTRY_WIDTH,
        -font         => $FONT,
        -textvariable => \$entry_text
    )->pack( -side => 'left' );

    my $submit_button = $frame->Button(
        -text    => 'Submit',
        -width   => $BUTTON_WIDTH,
        -font    => $FONT,
        -command => \&process_answer
      )->pack(
        -side => 'left',
        -padx => $PADX
      );

    $main_window->Label(
        -textvariable => \$status_label,
        -wraplength   => 490,
        -justify      => 'left',
        -height       => 2,
        -font         => $FONT
      )->pack(
        -side   => 'top',
        -padx   => $PADX,
        -pady   => $PADY,
        -anchor => 'w'
      );

    $main_window->Label(
        -textvariable => \$score_label,
        -wraplength   => 490,
        -justify      => 'left',
        -height       => 2,
        -font         => $FONT
      )->pack(
        -side   => 'top',
        -padx   => $PADX,
        -pady   => $PADY,
        -anchor => 'w'
      );

    # BINDINGS

    $main_window->bind( '<Return>' => sub { $submit_button->invoke } );

    $main_window->bind(
        '<Alt-Key-f>' => sub { $frame_menu->Post; Tk::Menu->Unpost } );

    $main_window->bind(
        '<Alt-Key-h>' => sub { $help_menu->Post; Tk::Menu->Unpost } );

    $main_window->bind(
        '<Alt-Key-m>' => sub {
            return if ( $correct_overall <= 0 or $correct_this_run <= 0 );
            $correct_overall--;
            $correct_this_run--;
            display_score();
            return;
        }
    );

    $main_window->bind(
        '<Alt-Key-p>' => sub {
            return
              if ( $correct_overall >= $questions_overall
                or $correct_this_run >= $questions_this_run );
            $correct_overall++;
            $correct_this_run++;
            display_score();
            return;
        }
    );

    return \%GUI;
}

sub get_file_basename {
    my ($file_full_path) = @_;

    my ($basename) = ( $file_full_path =~ $regex{file_basename} );

    return $basename;
}

sub is_blank {
    my ($input) = @_;

    return ( $input =~ $regex{non_space} ) ? 0 : 1;
}

sub regular_expressions {
    return (
        double_newline         => qr{\s*\n\s*\n\s*}xms,
        variable_definition    => qr{^\s*\+([A-Za-z_]\w*)=(.*)}xms,
        variable_interpolation => qr{\+([A-Za-z_]\w*)\b}xms,
        variable_interp_braces => qr{\+\{([A-Za-z_]\w*)\}}xms,
        question_mark          => qr{(?<=[?])}xms,
        file_basename          => qr{.*[\\/](.*)}xms,
        multiple_choice        => qr{\s*([A-Za-z]\).*)}xms,
        multiple_choice_line   => qr{^\s*[A-Za-z]\)}xms,
        multiple_choice_answer => qr{^\s*\*}xms,
        non_space              => qr{\S}xms,
        capital_letter         => qr{[A-Z]}xms,
        leading_space          => qr{^\s*}xms,
        trailing_space         => qr{\s*$}xms,
        multiple_spaces        => qr{\s+}xms,
    );
}

__END__

=head1 NAME

tkquiz.pl - A simple quiz program

=head1 SYNOPSIS

  tkquiz.pl

=head1 DESCRIPTION

B<tkquiz.pl> is a simple but flexible quiz program meant to take the place of
paper flash cards for memorization exercises during study.  You provide a file
with a set of questions and answers, and B<tkquiz.pl> will present you with the
questions, prompt you for answers, and check and tally your correct answers.

=head1 QUESTION/ANSWER FILES

Creating question/answer files for use with tkquiz is easy using an editor
such as B<Notepad>.  Files should have an extension of F<.qs> (for Question
Set), but this is not a requirement.

The basic format for a question/answer pair is a question, followed by a
question mark, followed by an answer.  Two newlines in a row indicate the
start of the next question/answer pair.  This is so you can have a question or
answer with multiple lines if desired.  Here is an example file:

    What shape has 4 sides of equal length and 4 right angles? square

    How many sides does a triangle have? 3

    Who was the first President of the United States? George Washington

Answers with all lowercase characters are case-insensitive.  This means that
in the above example, you may answer "square", "Square", or "SQUARE" as the
answer to the first question, and it will be counted as a correct answer.

An answer with at least one uppercase character will be considered
case-sensitive.  When answering the third question in the above example, an
answer of "george washington" will not be acceptable.  Only an answer of
"George Washington" will be counted correct.

Multiple-choice question/answers are possible as well.  They should appear in
the file as follows:

    Who was the first President of the United States?
    A) George Washington
    B) John Adams
    C) Ben Franklin
    D) Michael J. Nelson
    E) Norman Rockwell

The correct answer must be option A in the file.  B<tkquiz.pl> will scramble
the options each time the question is asked.  Options from A all the way to Z
can be specified if desired.

=head2 VARIABLES

It is possible to include variable text in your question/answer file.  This is
useful for repeated text in questions.  An example file:

    +sides=How many sides does a

    +{sides} triangle have? 3

    +{sides} square have? 4

    +{sides} pentagon have? 5

The first line, beginning C<+sides=> assigns the text "How many sides does a"
to the variable C<sides>.  Each subsequent line includes the text into the
question by including the expression C<+{sides}>.  This results in the
following question/answer pairs:

    How many sides does a triangle have? 3

    How many sides does a square have? 4

    How many sides does a pentagon have? 5

=head1 USING tkquiz.pl

Once your file has been saved, run B<tkquiz.pl>.  Select C<File>, then C<Open
Question Set> and select your file.  The first question will be presented to
you.  Type the answer and press C<Enter>.  B<tkquiz.pl> will let you know if
the answer is correct, and the tally and percentage correct will be updated
accordingly.

Alternatively, to save yourself a lot of typing, you can just say the answer
to yourself and press C<Enter>.  B<tkquiz.pl> will show you the correct answer
and ask you if you were correct.  This is also useful for foreign language
study, where you might want to practice saying a word as well as writing it.

If you use this alternative method, pressing C<Enter> or C<y> will indicate a
correct answer, while pressing C<n> will indicate an incorrect answer.  It
should never be necessary to use the mouse while running B<tkquiz.pl>.

=head1 SEE ALSO

The files F<example.qs> and F<example_with_variables.qs> which are included in
this distribution, for examples of how a question/answer file is built.

Visit L<http://www.tinypig.com> for
other I<tinypig> software and support.

=head1 AUTHOR

David Bradford, E<lt>davembradford@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by David Bradford

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut

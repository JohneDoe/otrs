# --
# HTML/Agent.pm - provides generic agent HTML output
# Copyright (C) 2001 Martin Edenhofer <martin+code@otrs.org>
# --
# $Id: Agent.pm,v 1.1 2001-12-23 13:27:18 martin Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

package Kernel::Output::HTML::Agent;

use strict;

use vars qw($VERSION);
$VERSION = '$Revision: 1.1 $';
$VERSION =~ s/^.*:\s(\d+\.\d+)\s.*$/$1/;

# --
sub NavigationBar {
    my $Self = shift;
    my %Param = @_;

    my $LockData = $Param{LockData};
    my %LockDataTmp = %$LockData;
    $Param{LockCount} = $LockDataTmp{Count} || 0;
    $Param{LockToDo} = $LockDataTmp{ToDo} || 0;

    # get output
    my $Output = $Self->Output(TemplateFile => 'AgentNavigationBar', Data => \%Param);

    # return output
    return $Output;
}
# --
sub QueueView {
    my $Self = shift;
    my %Param = @_;
    my $QueueStrg = '';
    my $QueueID = $Param{QueueID} || 0;
    my $QueuesTmp = $Param{Queues};
    my @QueuesNew = @$QueuesTmp;
    my $QueueIDOfMaxAge = $Param{QueueIDOfMaxAge} || '?';
    $Self->{HighlightAge1} = $Self->{ConfigObject}->Get('HighlightAge1');
    $Self->{HighlightAge2} = $Self->{ConfigObject}->Get('HighlightAge2');
    $Self->{HighlightColor1} = $Self->{ConfigObject}->Get('HighlightColor1');
    $Self->{HighlightColor2} = $Self->{ConfigObject}->Get('HighlightColor2'); 
 
    # build queue string
    foreach my $QueueRef (@QueuesNew) {
        my %Queue = %$QueueRef;
        $Queue{MaxAge} = $Queue{MaxAge} / 60;
        # should i highlight this queue
        if ($QueueID eq $Queue{QueueID}) {
           $QueueStrg .= '<B>';
           $Param{SelectedQueue} = $Queue{Queue};
        }
        $QueueStrg .= "<A HREF=\"$Self->{Baselink}&Action=AgentQueueView&QueueID=$Queue{QueueID}\">";
        # should i highlight this queue
        if ($Queue{MaxAge} >= $Self->{HighlightAge2}) {
            $QueueStrg .= "<FONT COLOR=$Self->{HighlightColor2}>";
        }
        elsif ($Queue{MaxAge} >= $Self->{HighlightAge1}) {
            $QueueStrg .= "<FONT COLOR=$Self->{HighlightColor1}>";
        }
        # the oldest queue
        if ($Queue{QueueID} == $QueueIDOfMaxAge) {
            $QueueStrg .= "<BLINK>";
        }
        # QueueStrg
        $QueueStrg .= "$Queue{Queue} ($Queue{Count})";
        # the oldest queue
        if ($Queue{QueueID} == $QueueIDOfMaxAge) {
            $QueueStrg .= "</BLINK>";
        }
        # should i highlight this queue
        if ($Queue{MaxAge} >= $Self->{HighlightAge1}
              || $Queue{MaxAge} >= $Self->{HighlightAge2}) {
            $QueueStrg .= "</FONT>";
        }
        $QueueStrg .= "</A>";
        # should i highlight this queue
        if ($QueueID eq $Queue{QueueID}) {
           $QueueStrg .= '</B>';
        }
        $QueueStrg .= ' - ';
    }
    $Param{QueueStrg} = $QueueStrg;

    # get output
    my $Output = $Self->Output(TemplateFile => 'QueueView', Data => \%Param);

    # return output
    return $Output;
}
# --
sub TicketView {
    my $Self = shift;
    my %Param = @_;

    # do some html quoting
    foreach ('From', 'To', 'Cc', 'Subject', 'Priority', 'State') {
        $Param{$_} = $Self->Ascii2Html(Text => $Param{$_}, Max => 50, MIME => 1) || '';
    }
    $Param{Age} = $Self->CustomerAge(Age => $Param{Age}, Space => ' ');

    # do some text quoting
    $Param{Text} = $Self->Ascii2Html(Text => $Param{Text});
    $Param{Text} = $Self->LinkQuote(Text => $Param{Text});

    # get MoveQueuesStrg
    $Param{MoveQueuesStrg} = $Self->OptionStrgHashRef(
        Name => 'DestQueueID',
        Selected => $Param{QueueID},
        Data => $Param{MoveQueues},
    );

    # create output
    my $Output = $Self->Output(TemplateFile => 'TicketView', Data => \%Param);

    # return output
    return $Output;
}
# --
sub TicketZoom {
    my $Self = shift;
    my %Param = @_;

    # do some html quoting
    foreach ('From', 'To', 'Cc', 'Subject', 'Priority', 'State') {
        $Param{$_} = $Self->Ascii2Html(Text => $Param{$_}, Max => 50, MIME => 1) || '';
    }
    $Param{Age} = $Self->CustomerAge(Age => $Param{Age}, Space => ' ');

    $Param{Owner} = $Self->Ascii2Html(Text => $Param{Owner}, Max => 20) || ''; 

    # do some text quoting
    $Param{Text} = $Self->Ascii2Html(Text => $Param{Text});
    $Param{Text} = $Self->LinkQuote(Text => $Param{Text});

    # get MoveQueuesStrg
    $Param{MoveQueuesStrg} = $Self->OptionStrgHashRef(
        Name => 'DestQueueID',
        Selected => $Param{QueueID},
        Data => $Param{MoveQueues},
    );

    # build article stuff
    $Param{ArticleStrg} = '';
    my $ArticleID = $Param{ArticleID} || '';
    my $BaseLink = $Self->{Baselink} . "&TicketID=$Self->{TicketID}&QueueID=$Self->{QueueID}";
    my $ArticleBoxTmp = $Param{ArticleBox};
    my @ArticleBox = @$ArticleBoxTmp;
    my $MoveQueues = $Param{MoveQueues};
    my $StdResponses = $Param{StdResponses};
    my $ThreadStrg = '<FONT SIZE="-1">';
    my $Counter = '';
    my $Space = '';
    my $CounterArray = 0;
    my $LastSenderType = '';
    my $LastCustomerArticleID;
    my $LastCustomerArticle = $#ArticleBox;

    foreach my $ArticleTmp (@ArticleBox) {
        my %Article = %$ArticleTmp;
        # if it is a customer article
        if ($Article{SenderType} eq 'customer') {
            $LastCustomerArticleID = $Article{'ArticleID'};
            $LastCustomerArticle = $CounterArray;
        }
        $CounterArray++;
    }

    foreach my $ArticleTmp (@ArticleBox) {
        my %Article = %$ArticleTmp;
        if ($LastSenderType ne $Article{SenderType}) {
            $Counter .= "&nbsp;&nbsp;&nbsp;&nbsp;";
            $Space = "$Counter |-->";
        }
        $LastSenderType = $Article{SenderType};
        $ThreadStrg .= "$Space";

        # if this is the shown article 
        if ($ArticleID eq $Article{ArticleID} ||
                 (!$ArticleID && $LastCustomerArticleID eq $Article{ArticleID})) {
            $ThreadStrg .= ">><B>";
        }

        # the full thread string
        $ThreadStrg .= "<A HREF=\"$BaseLink&Action=AgentZoom&ArticleID=$Article{ArticleID}\">" .
        "$Article{SenderType} ($Article{ArticleType})</A> ";
        if ($Article{ArticleType} eq 'email') {
            $ThreadStrg .= " (<A HREF=\"$BaseLink&Action=AgentPlain&ArticleID=$Article{ArticleID}\">" .
            $Self->{LanguageObject}->Get('plain') . "</A>)";
        }
        $ThreadStrg .= " $Article{CreateTime}";
        $ThreadStrg .= "<BR>";

        # if this is the shown article
        if ($ArticleID eq $Article{ArticleID} ||
                 (!$ArticleID && $LastCustomerArticleID eq $Article{ArticleID})) {
            $ThreadStrg .= "</B>";
        }
    }
    $ThreadStrg .= '</FONT>';
    $Param{ArticleStrg} .= $ThreadStrg;

    my $ArticleOB = $ArticleBox[$LastCustomerArticle];
    my %Article = %$ArticleOB;

    my $ArticleArray = 0;
    foreach my $ArticleTmp (@ArticleBox) {
        my %ArticleTmp1 = %$ArticleTmp;
        if ($ArticleID eq $ArticleTmp1{ArticleID}) {
            %Article = %ArticleTmp1;
        }
    }

    # do some strips && quoting
    foreach ('To', 'Cc', 'From', 'Subject') {
        $Param{"Article::$_"} = $Self->Ascii2Html(Text => $Article{$_}, Max => 70, MIME => 1);
    }
    $Article{Text} =~ s/^(.{32766}).*$/$1 [...]/g;
    $Article{Text} =~ s/^(.{100}).*$/$1 [.]/gmi;
    $Param{"Article::Text"} = $Self->Ascii2Html(Text => $Article{Text});
    $Param{"Article::Text"} = $Self->LinkQuote(Text => $Param{"Article::Text"}); 

    my $Output = '';
    if ($Article{ArticleType} =~ /^note/i) {
        $Output = $Self->Output(TemplateFile => 'TicketZoomNote', Data => \%Param);
    }
    else {
        $Output = $Self->Output(TemplateFile => 'TicketZoom', Data => \%Param);
    }

    # return output
    return $Output;
}
# --
sub ArticlePlain {
    my $Self = shift;
    my %Param = @_;

    # do some highlightings
    $Param{Text} =~ s/^((From|To|Cc|Subject|Reply-To|Organization|X-Company):.*)/<font color=\"red\">$1<\/font>/gm;
    $Param{Text} =~ s/^(Date:.*)/<FONT COLOR=777777>$1<\/font>/m;
    $Param{Text} =~ s/^((X-Mailer|User-Agent|X-OS):.*(Mozilla|Win?|Outlook|Microsoft|Internet Mail Service).*)/<blink>$1<\/blink>/gmi;
    $Param{Text} =~ s/(^|^<blink>)((X-Mailer|User-Agent|X-OS|X-Operating-System):.*)/<font color=\"blue\">$1$2<\/font>/gmi;
    $Param{Text} =~ s/^((Resent-.*):.*)/<font color=\"green\">$1<\/font>/gmi;
    $Param{Text} =~ s/^(From .*)/<font color=\"gray\">$1<\/font>/gm;
    $Param{Text} =~ s/^(X-OTRS.*)/<font color=\"#99BBDD\">$1<\/font>/gmi;

    # get output
    my $Output = $Self->Output(TemplateFile => 'AgentPlain', Data => \%Param);

    # return output
    return $Output;
}
# --
sub Note {
    my $Self = shift;
    my %Param = @_;

    # build ArticleTypeID string
    $Param{'NoteStrg'} = $Self->OptionStrgHashRef(
        Data => $Param{NoteTypes},
        Name => 'ArticleTypeID'
    );

    # get output
    my $Output = $Self->Output(TemplateFile => 'AgentNote', Data => \%Param);

    # return output
    return $Output;
}
# --
sub AgentPriority {
    my $Self = shift;
    my %Param = @_;

    # build ArticleTypeID string
    $Param{'OptionStrg'} = $Self->OptionStrgHashRef(
        Data => $Param{OptionStrg},
        Name => 'PriorityID'
    );

    # get output
    my $Output = $Self->Output(TemplateFile => 'AgentPriority', Data => \%Param);

    # return output
    return $Output;
}
# --
sub AgentClose {
    my $Self = shift;
    my %Param = @_;

    # build string
    $Param{'NextStatesStrg'} = $Self->OptionStrgHashRef(
        Data => $Param{NextStatesStrg},
        Name => 'StateID'
    );

    # build string
    $Param{'NoteTypesStrg'} = $Self->OptionStrgHashRef(
        Data => $Param{NoteTypesStrg},
        Name => 'NoteID'
    );


    # get output
    my $Output = $Self->Output(TemplateFile => 'AgentClose', Data => \%Param);

    # return output
    return $Output;
}
# --
sub AgentUtilForm {
    my $Self = shift;
    my %Param = @_;

    # get output
    my $Output = $Self->Output(TemplateFile => 'AgentUtilForm', Data => \%Param);

    # return output
    return $Output;
}
# --
sub AgentUtilSearchAgain {
    my $Self = shift;
    my %Param = @_;

    # get output
    my $Output = $Self->Output(TemplateFile => 'AgentUtilSearchAgain', Data => \%Param);

    # return output
    return $Output;
}
# --
sub AgentUtilSearchResult {
    my $Self = shift;
    my %Param = @_;
    my $Highlight = $Param{Highlight} || 0;
    my $HighlightStart = '<font color="orange"><b><i>';
    my $HighlightEnd = '</i></b></font>';
    my $TextLongMax = $Param{TextLongMax} || 550;
    my $TextWidthMax = $Param{TextWidthMax} || 100;

    $Self->{UtilSearchResultCounter}++;

    $Param{Age} = $Self->CustomerAge(Age => $Param{Age}, Space => ' ') || 0;

    # do some strips
    $Param{Text} =~ s/^\s*\n//mg;
    $Param{Text} =~ s/^(.{$TextWidthMax}).*$/$1 [...]/gmi;
    $Param{Text} =~ s/^(.{$TextLongMax}).*$/$1 [...]/ois;
    if ($Highlight) {
        # do some html highlighting
        my @SParts = split('%', $Param{What});
        $Param{Text} =~ s/(${\(join('|', @SParts))})/$HighlightStart$1$HighlightEnd/gi;
        $Param{From} =~ s/(${\(join('|', @SParts))})/$HighlightStart$1$HighlightEnd/gi;
        $Param{Subject} =~ s/(${\(join('|', @SParts))})/$HighlightStart$1$HighlightEnd/gi;
    }

    # get output
    my $Output = $Self->Output(TemplateFile => 'AgentUtilSearchResult', Data => \%Param);

    # return output
    return $Output;
}
# --
sub AgentUtilSearchCouter {
    my $Self = shift;
    my %Param = @_;
    my $Limit = $Param{Limit} || 0;
    my $Output = '';
    $Self->{UtilSearchResultCounter} = 0 if (!$Self->{UtilSearchResultCounter});
    if ($Limit == $Self->{UtilSearchResultCounter}) {
    $Output = "<B>${\$Self->{LanguageObject}->Get('Total hits')}: &gt;<FONT COLOR=RED>" .
    $Self->{UtilSearchResultCounter} . "</FONT></B><BR>";
    }
    else {
    $Output = "<B>${\$Self->{LanguageObject}->Get('Total hits')}: $Self->{UtilSearchResultCounter}</B><BR>";
    }
    return $Output;
}
# --

1;
 

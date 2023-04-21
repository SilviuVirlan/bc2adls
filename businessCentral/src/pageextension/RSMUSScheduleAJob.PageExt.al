pageextension 82661 "RSMUS Schedule A Job" extends "Schedule a Job" //676
{
    layout
    {
        addlast(content)
        {
            group(RSMUSRecurrence)
            {
                Caption = 'Recurrence';
                Editable = Rec.Status = Rec.Status::"On Hold";

                field("RSMUSRecurring Job"; Rec."Recurring Job")
                {
                    ApplicationArea = Basic, Suite;
                    Editable = false;
                    ToolTip = 'Specifies if the job queue entry is recurring. If the Recurring Job check box is selected, then the job queue entry is recurring. If the check box is cleared, the job queue entry is not recurring. After you specify that a job queue entry is a recurring one, you must specify on which days of the week the job queue entry is to run. Optionally, you can also specify a time of day for the job to run and how many minutes should elapse between runs.';
                }
                field("RSMUSRun on Mondays"; Rec."Run on Mondays")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies that the job queue entry runs on Mondays.';
                }
                field("RSMUSRun on Tuesdays"; Rec."Run on Tuesdays")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies that the job queue entry runs on Tuesdays.';
                }
                field("RSMUSRun on Wednesdays"; Rec."Run on Wednesdays")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies that the job queue entry runs on Wednesdays.';
                }
                field("RSMUSRun on Thursdays"; Rec."Run on Thursdays")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies that the job queue entry runs on Thursdays.';
                }
                field("RSMUSRun on Fridays"; Rec."Run on Fridays")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies that the job queue entry runs on Fridays.';
                }
                field("RSMUSRun on Saturdays"; Rec."Run on Saturdays")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies that the job queue entry runs on Saturdays.';
                }
                field("RSMUSRun on Sundays"; Rec."Run on Sundays")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies that the job queue entry runs on Sundays.';
                }
                field("RSMUSNext Run Date Formula"; Rec."Next Run Date Formula")
                {
                    ApplicationArea = Basic, Suite;
                    Importance = Promoted;
                    ToolTip = 'Specifies the date formula that is used to calculate the next time the recurring job queue entry will run. If you use a date formula, all other recurrence settings are cleared.';
                }
                field("RSMUSStarting Time"; Rec."Starting Time")
                {
                    ApplicationArea = Basic, Suite;
                    Editable = Rec."Recurring Job" = TRUE;
                    Importance = Promoted;
                    ToolTip = 'Specifies the earliest time of the day that the recurring job queue entry is to be run.';
                }
                field("RSMUSEnding Time"; Rec."Ending Time")
                {
                    ApplicationArea = Basic, Suite;
                    Editable = Rec."Recurring Job" = TRUE;
                    Importance = Promoted;
                    ToolTip = 'Specifies the latest time of the day that the recurring job queue entry is to be run.';
                }
                field("RSMUSNo. of Minutes between Runs"; Rec."No. of Minutes between Runs")
                {
                    ApplicationArea = Basic, Suite;
                    Editable = Rec."Recurring Job" = TRUE;
                    Importance = Promoted;
                    ToolTip = 'Specifies the minimum number of minutes that are to elapse between runs of a job queue entry. The value cannot be less than one minute. This field only has meaning if the job queue entry is set to be a recurring job. If you use a no. of minutes between runs, the date formula setting is cleared.';
                }
                field("RSMUSInactivity Timeout Period"; Rec."Inactivity Timeout Period")
                {
                    ApplicationArea = Basic, Suite;
                    MinValue = 5;
                    ToolTip = 'Specifies the number of minutes that pass before a recurring job that has the status On Hold With Inactivity Timeout is automatically restated. The value cannot be less than five minutes.';
                }
                label(Control33)
                {
                    ApplicationArea = Basic, Suite;
                    ShowCaption = false;
                    Caption = '';
                }
                label(Control31)
                {
                    ApplicationArea = Basic, Suite;
                    ShowCaption = false;
                    Caption = '';
                }
                label(Control22)
                {
                    ApplicationArea = Basic, Suite;
                    ShowCaption = false;
                    Caption = '';
                }
            }
        }
    }
}
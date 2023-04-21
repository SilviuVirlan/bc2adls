pageextension 82660 "RSMUS Admin Ext." extends "Administrator Role Center" //9018
{
    layout
    {

    }

    actions
    {
        addfirst(Sections)
        {
            group(RSMUSADLSE)
            {
                Caption = 'BC-2-ODS';
                ToolTip = 'Export to ODS Azure Data Lake Storage';

                action("RSMUSADLSE Configuration")
                {
                    Caption = 'BC-2-ODS Setup';
                    ApplicationArea = All;
                    RunObject = page "RSMUS Setup";
                    RunPageMode = Edit;
                    Image = Database;
                    ToolTip = 'Provide configuration setup info for the ODS ADLSE Process.';
                }
            }
        }
    }
}
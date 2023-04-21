pageextension 82662 "RSMUS Job Queue Entries" extends "Job Queue Entries"
{
    actions
    {
        addlast("Job &Queue")
        {
            action("RSMUSADLSE Refresh")
            {
                ApplicationArea = All;
                Caption = 'Refresh';
                Image = Refresh;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Get refreshed data';

                trigger OnAction()
                begin
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
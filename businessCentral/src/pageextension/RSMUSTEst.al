pageextension 82663 CustomerExt extends "Customer List"
{
    actions
    {
        // Add changes to page actions here
        addafter("Customer - Sales List")
        {
            action("MyAction")
            {
                ApplicationArea = All;
                Caption = 'My Action';
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'My Action';
                trigger OnAction()
                var
                    _cu: Codeunit 82661;
                    _rec: Record "RSMUS Table";
                begin
                    _rec.Get(3);
                    _cu.Run(_rec);
                end;
            }
        }
    }

    var
        myInt: Integer;
}
// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
table 82662 "RSMUS Field"
{
    Access = Internal;
    DataClassification = CustomerContent;
    DataPerCompany = false;

    fields
    {
        field(1; "Table ID"; Integer)
        {
            Editable = false;
            Caption = 'Table ID';
        }
        field(2; "Field ID"; Integer)
        {
            Editable = false;
            Caption = 'Field ID';
        }
        field(3; Enabled; Boolean)
        {
            Caption = 'Enabled';

            trigger OnValidate()
            begin
                if Rec.Enabled then
                    Rec.CheckFieldToBeEnabled();
            end;
        }
        field(100; FieldCaption; Text[80])
        {
            Caption = 'Field';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup(Field."Field Caption" where("No." = field("Field ID"), TableNo = field("Table ID")));
        }
    }

    keys
    {
        key(Key1; "Table ID", "Field ID")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    var
        rsmusSetup: Record "RSMUS Setup";
    begin
        rsmusSetup.CheckNoSimultaneousExportsAllowed();
    end;

    trigger OnModify()
    var
        rsmusSetup: Record "RSMUS Setup";
        rsmusTable: Record "RSMUS Table";
    begin
        rsmusSetup.CheckNoSimultaneousExportsAllowed();

        rsmusTable.Get(Rec."Table ID");
        rsmusTable.CheckNotExporting();
    end;

    trigger OnDelete()
    var
        rsmusSetup: Record "RSMUS Setup";
    begin
        rsmusSetup.CheckNoSimultaneousExportsAllowed();
    end;

    procedure InsertForTable(rsmusTable: Record "RSMUS Table")
    var
        Fld: Record Field;
        rsmusField: Record "RSMUS Field";
    begin
        Fld.SetRange(TableNo, rsmusTable."Table ID");
        Fld.SetFilter("No.", '<%1', 2000000000); // no system fields

        if Fld.FindSet() then
            repeat
                if not rsmusField.Get(rsmusTable."Table ID", Fld."No.") then begin
                    Rec."Table ID" := Fld.TableNo;
                    Rec."Field ID" := Fld."No.";
                    Rec.Enabled := false;
                    Rec.Insert();
                end;
            until Fld.Next() = 0;
    end;

    procedure CheckFieldToBeEnabled()
    var
        Fld: Record Field;
        rsmusSetup: Codeunit "RSMUS Setup";
        rsmusUtil: Codeunit "RSMUS Util";
    begin
        Fld.Get(Rec."Table ID", Rec."Field ID");
        rsmusUtil.CheckFieldTypeForExport(Fld);
        rsmusSetup.CheckFieldCanBeExported(Fld);
    end;

    [TryFunction]
    procedure CanFieldBeEnabled()
    begin
        CheckFieldToBeEnabled();
    end;
}
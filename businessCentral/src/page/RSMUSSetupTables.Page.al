// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
page 82661 "RSMUS Setup Tables"
{
    Caption = 'Tables';
    LinksAllowed = false;
    PageType = ListPart;
    SourceTable = "RSMUS Table";
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(content)
        {
            repeater(Control1)
            {
                ShowCaption = false;

                field(TableCaption; TableCaptionValue)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'Table';
                    Tooltip = 'Specifies the caption of the table whose data is to exported.';
                }
                field(Enabled; Rec.Enabled)
                {
                    ApplicationArea = All;
                    Editable = true;
                    Caption = 'Enabled';
                    Tooltip = 'Specifies the state of the table. Set this checkmark to export this table, otherwise not.';
                }
                field(FieldsChosen; NumberFieldsChosenValue)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = '# Fields selected';
                    Tooltip = 'Shows if any field has been chosen to be exported. Click on Choose Fields action to add fields to export.';

                    trigger OnDrillDown()
                    begin
                        DoChooseFields();
                    end;
                }
                field(ADLSTableName; ADLSEntityName)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'Entity name';
                    Tooltip = 'The name of the entity corresponding to this table on the data lake. The value at the end indicates the table number in Dynamics 365 Business Central.';
                }
                field(Status; LastRunState)
                {
                    ApplicationArea = All;
                    Caption = 'Last exported state';
                    Editable = false;
                    Tooltip = 'Specifies the status of the last export from this table in this company.';
                }
                field(LastRanAt; LastStarted)
                {
                    ApplicationArea = All;
                    Caption = 'Last started at';
                    Editable = false;
                    Tooltip = 'Specifies the time of the last export from this table in this company.';
                }
                field(LastError; LastRunError)
                {
                    ApplicationArea = All;
                    Caption = 'Last error';
                    Editable = false;
                    ToolTip = 'Specifies the error message from the last export of this table in this company.';
                }
                field(LastTimestamp; UpdatedLastTimestamp)
                {
                    ApplicationArea = All;
                    Tooltip = 'The timestamp of the record in this table that was exported last.';
                    Caption = 'Last timestamp';
                    Visible = false;
                }
                field(LastTimestampDeleted; DeletedRecordLastEntryNo)
                {
                    ApplicationArea = All;
                    Tooltip = 'The timestamp of the deleted records in this table that was exported last.';
                    Caption = 'Last timestamp deleted';
                    Visible = false;
                }
                field(ActualRowCount; ActualRowCount)
                {
                    Caption = 'Actual Row Count';
                    ToolTip = 'Displays the actual row count of the table.';
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AddTable)
            {
                ApplicationArea = All;
                Caption = 'Add';
                Tooltip = 'Add a table to be exported';
                Image = New;
                Enabled = NoExportInProgress;

                trigger OnAction()
                var
                    rsmusSetup: Codeunit "RSMUS Setup";
                begin
                    rsmusSetup.AddTableToExport();
                    CurrPage.Update();
                end;
            }

            action(DeleteTable)
            {
                ApplicationArea = All;
                Caption = 'Delete';
                Tooltip = 'Removes a table that had been added to the list meant for export';
                Image = Delete;
                Enabled = NoExportInProgress;

                trigger OnAction()
                begin
                    Rec.Delete(true);
                    CurrPage.Update();
                end;
            }

            action(ChooseFields)
            {
                ApplicationArea = All;
                Caption = 'Choose fields';
                ToolTip = 'Select the fields of this table to be exported';
                Image = SelectEntries;
                Enabled = NoExportInProgress;

                trigger OnAction()
                begin
                    DoChooseFields();
                end;
            }

            action(Reset)
            {
                ApplicationArea = All;
                Caption = 'Reset';
                ToolTip = 'Set the selected tables to export all of its data again.';
                Image = ResetStatus;
                Enabled = NoExportInProgress;

                trigger OnAction()
                var
                    SelectedrsmusTable: Record "RSMUS Table";
                begin
                    CurrPage.SetSelectionFilter(SelectedrsmusTable);
                    SelectedrsmusTable.ResetSelected();
                    CurrPage.Update();
                end;
            }

            action(Logs)
            {
                ApplicationArea = All;
                Caption = 'Execution logs';
                ToolTip = 'View the execution logs for this table in the currently opened company.';
                Image = Log;

                trigger OnAction()
                var
                    rsmusRun: Page "RSMUS Exported Tables Tracking";
                begin
                    rsmusRun.SetDisplayForTable(Rec."Table ID");
                    rsmusRun.Run();
                end;

            }
        }
    }

    trigger OnInit()
    var
        rsmusCurrentSession: Record "RSMUS Current Session";
    begin
        NoExportInProgress := not rsmusCurrentSession.AreAnySessionsActive();
    end;

    trigger OnAfterGetRecord()
    var
        TableMetadata: Record "Table Metadata";
        rsmusTableLastTimestamp: Record "RSMUS Table Tracking";
        rsmusRun: Record "RSMUS Runs Log";
        rsmusUtil: Codeunit "RSMUS Util";
        RecRef: RecordRef;
    begin
        if TableMetadata.Get(Rec."Table ID") then begin
            TableCaptionValue := rsmusUtil.GetTableCaption(Rec."Table ID");
            NumberFieldsChosenValue := Rec.FieldsChosen();
            UpdatedLastTimestamp := rsmusTableLastTimestamp.GetUpdatedLastTimestamp(Rec."Table ID");
            DeletedRecordLastEntryNo := rsmusTableLastTimestamp.GetDeletedLastEntryNo(Rec."Table ID");
            ADLSEntityName := rsmusUtil.GetDataLakeCompliantTableName(Rec."Table ID");
        end else begin
            TableCaptionValue := StrSubstNo(AbsentTableCaptionLbl, Rec."Table ID");
            NumberFieldsChosenValue := 0;
            UpdatedLastTimestamp := 0;
            DeletedRecordLastEntryNo := 0;
            ADLSEntityName := '';
            Rec.Modify();
        end;
        RecRef.Open(Rec."Table ID", false);

        RecRef.LockTable();

        ActualRowCount := RecRef.Count;

        rsmusRun.GetLastRunDetails(Rec."Table ID", LastRunState, LastStarted, LastRunError);

        IssueNotificationIfInvalidFieldsConfiguredToBeExported();
    end;

    var
        TableCaptionValue: Text;
        NumberFieldsChosenValue: Integer;
        ADLSEntityName: Text;
        UpdatedLastTimestamp: BigInteger;
        DeletedRecordLastEntryNo: BigInteger;
        AbsentTableCaptionLbl: Label 'Table%1', Comment = '%1 = Table ID';
        LastRunState: Enum "RSMUS Run State";
        LastStarted: DateTime;
        LastRunError: Text[2048];
        NoExportInProgress: Boolean;
        InvalidFieldConfiguredMsg: Label 'The following fields have been incorrectly enabled for exports in the table %1: %2', Comment = '%1 = table name; %2 = List of invalid field names';
        ActualRowCount: Integer;

    local procedure DoChooseFields()
    var
        rsmusSetup: Codeunit "RSMUS Setup";
    begin
        rsmusSetup.ChooseFieldsToExport(Rec);
        CurrPage.Update();
    end;

    local procedure IssueNotificationIfInvalidFieldsConfiguredToBeExported()
    var
        rsmusUtil: Codeunit "RSMUS Util";
        InvalidFieldNotification: Notification;
        InvalidFieldList: List of [Text];
    begin
        InvalidFieldList := Rec.ListInvalidFieldsBeingExported();
        if InvalidFieldList.Count() = 0 then
            exit;
        InvalidFieldNotification.Message := StrSubstNo(InvalidFieldConfiguredMsg, TableCaptionValue, rsmusUtil.Concatenate(InvalidFieldList));
        InvalidFieldNotification.Scope := NotificationScope::LocalScope;
        InvalidFieldNotification.Send();
    end;
}
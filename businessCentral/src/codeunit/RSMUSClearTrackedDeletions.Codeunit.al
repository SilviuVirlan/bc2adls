// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82673 "RSMUS Clear Tracked Deletions"
{
    /// This codeunit removes the tracked deleted records- those that track deletions of records from tables being exported, so 
    /// that the data lake becomes aware of them and removes those records from the final set of records. Once, these trackings 
    /// have been exported to the data lake, they are no more required. This codeunit removes such records and may be invoked
    /// from a job queue that runs at a low- frequency and periodically flushes such data to manage storage space.

    Access = Internal;

    trigger OnRun()
    begin
        ClearTrackedDeletedRecords();
    end;

    var
        TrackedDeletedRecordsRemovedMsg: Label 'Representations of deleted records that have been exported previously have been deleted.';

    local procedure ClearTrackedDeletedRecords()
    var
        rsmusTable: Record "RSMUS Table";
        rsmusTableLastTimestamp: Record "RSMUS Table Tracking";
        rsmusDeletedRecord: Record "RSMUS Deleted Record";
    begin
        rsmusTable.SetLoadFields("Table ID");
        if rsmusTable.FindSet() then
            repeat
                rsmusDeletedRecord.SetRange("Table ID", rsmusTable."Table ID");
                rsmusDeletedRecord.SetFilter("Entry No.", '<=%1', rsmusTableLastTimestamp.GetDeletedLastEntryNo(rsmusTable."Table ID"));
                rsmusDeletedRecord.DeleteAll();

                rsmusTableLastTimestamp.SaveDeletedLastEntryNo(rsmusTable."Table ID", 0);
            until rsmusTable.Next() = 0;
        Message(TrackedDeletedRecordsRemovedMsg);
    end;
}
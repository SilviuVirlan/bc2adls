table 82667 "RSMUS Detailed Runs Log"
{
    Access = Internal;
    DataClassification = SystemMetadata;
    DataPerCompany = false;

    fields
    {
        field(1; "Run ID"; Integer)
        {
            Editable = false;
            Caption = 'Run ID';
        }
        field(2; "Table ID"; Integer)
        {
            Editable = false;
            Caption = 'Table ID';
        }
        field(3; "Session ID"; Integer)
        {
            Editable = false;
            Caption = 'Session ID';
        }
        field(4; "Session Unique ID"; Guid)
        {
            Editable = false;
            Caption = 'Session unique ID';
        }
        field(5; "Elapsed Time"; Duration)
        {
            Editable = false;
            Caption = 'Elapsed Time';
        }
    }

    keys
    {
        key(Key1; "Run ID", "Table ID")
        {
            Clustered = true;
        }
    }
}
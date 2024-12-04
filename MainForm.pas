﻿unit MainForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Generics.Collections, System.IOUtils, FMX.Types, FMX.Controls,
  FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Layouts, FMX.Objects,
  FMX.ExtCtrls, FMX.Ani, FMX.Edit, FMX.ScrollBox, FMX.Memo, FMX.StdCtrls,
  FMX.WebBrowser, FireDAC.Stan.Intf, FireDAC.Phys.Intf,
  FireDAC.Comp.Client,
  FireDAC.Comp.DataSet, FireDAC.Stan.Param, FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef, Data.DB, FMX.Skia, System.Net.HttpClient,
  System.Hash, ScryfallAPIWrapperV2, SGlobalsZ, DataModuleUnit, HighResForm,

  CardCollectionForm, MLogic, System.JSON, REST.JSON, System.StrUtils,
  System.TypInfo, System.NetEncoding, Math, System.Threading,
  FMX.Controls.Presentation, FMX.ListView.Types, FMX.ListView.Appearances,
  FMX.ListView.Adapters.Base, FMX.ListView, FMX.ListBox,CardDisplayHelpers;

type
  TCardDetailsObject = class(TObject)
  public
    CardDetails: TCardDetails;
    constructor Create(const ACardDetails: TCardDetails);
  end;

  TCardLayout = class(TLayout)
  public
    destructor Destroy; override;
  end;

  TForm1 = class(TForm)
    Button1: TButton;
    Edit1: TEdit;
    Button4: TButton;
    Button5: TButton;
    ShowHighResButton: TButton;
    ProgressBar1: TProgressBar;
    WebBrowser1: TWebBrowser;
    DelayTimer: TTimer;
    ListViewCards: TListView;
    StyleBook1: TStyleBook;
    ComboBoxSetCode: TComboBox;
    ComboBoxColors: TComboBox;
    ComboBoxRarity: TComboBox;
    CountLabel: TLabel;
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ShowHighResButtonClick(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure DelayTimerTimer(Sender: TObject);
    procedure ListViewCardsItemClick(const Sender: TObject;
      const AItem: TListViewItem);
    procedure ListViewCardsButtonClick(const Sender: TObject;
      const AItem: TListItem; const AObject: TListItemSimpleControl);

  private
    HttpClient: THTTPClient;
    FCardDetailsObject: TCardDetailsObject; // Private field
    CardTitle: string; // Private field
    CardDataList: TList<TCardDetails>;
    // Encapsulated within the form
    CardCount: Integer; // Encapsulated within the form
    AppClose: Boolean; // Encapsulated within the form
    FScryfallAPI: TScryfallAPI; // Instance of TScryfallAPI



    BrIsLoaded: Boolean;
    procedure DisplayCardArtworks(const CardName: string);

    procedure ShowCardDetails(Sender: TObject);

    procedure SaveSelectedCardToDatabase;
    procedure ShowCardCollection;

    procedure DisplayCardInBrowser(const CardDetails: TCardDetails;
      const Rulings: TArray<TRuling>);

    procedure AddCardToListView(const Card: TCardDetails);
    function IsCardValid(const Card: TCardDetails): Boolean;

  public
    // Public declarations
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}
{$R *.Windows.fmx MSWINDOWS}
{$R *.NmXhdpiPh.fmx ANDROID}
{$R *.LgXhdpiPh.fmx ANDROID}
{$R *.SmXhdpiPh.fmx ANDROID}
{$R *.LgXhdpiTb.fmx ANDROID}
{$R *.XLgXhdpiTb.fmx ANDROID}
{ TCardLayout }

destructor TCardLayout.Destroy;
begin
  FreeAndNil(TagObject);
  inherited;
end;

{ TCardDetailsObject }

constructor TCardDetailsObject.Create(const ACardDetails: TCardDetails);
begin
  inherited Create;
  CardDetails := ACardDetails;
end;

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
var
  SetDetailsArray: TArray<TSetDetails>;
  SetDetails: TSetDetails;
begin
  FScryfallAPI := TScryfallAPI.Create;
  HttpClient := THTTPClient.Create;
  CardDataList := TList<TCardDetails>.Create;
  // DataModule1.CreateCardDetailsTable;
  CardCount := 0;
  AppClose := False;
  DataModule1.SetupDatabaseConnection(GetDatabasePath);
  CopyDatabaseToInternalStorage;
  CopyTemplateToInternalStorage;
  // InitializeManaSymbolMap;
  FBase64ImageCache := TDictionary<string, string>.Create;
  BrIsLoaded := False;

  // WebBrowser1.URL := 'about:blank';

  ListViewCards.OnItemClick := ListViewCardsItemClick;

  ComboBoxSetCode.Items.Add('All Sets');

  try
    //FScryfallAPI.PreloadAllSets;
   // SetDetailsArray := FScryfallAPI.GetAllSets;
    // Fetch all sets from Scryfall
    for SetDetails in SetDetailsArray do
    begin
      //ComboBoxSetCode.Items.Add(SetDetails.Code + ' - ' + SetDetails.Name);
      // Example: "KHM - Kaldheim"
    end;
  finally

    ComboBoxSetCode.ItemIndex := 0;
    ComboBoxColors.ItemIndex := 0;
    ComboBoxRarity.ItemIndex := 0;
  end;
DelayTimer.Enabled := True;
  // Form1.StyleBook := HighResForm.HighResImageForm.StyleBook1;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  AppClose := True;
  if Assigned(HttpClient) then
    FreeAndNil(HttpClient);
  if Assigned(CardDataList) then
    FreeAndNil(CardDataList);
  // FreeAndNil(FManaSymbolMap);
  FreeAndNil(FBase64ImageCache);
  FScryfallAPI.Free;
end;

procedure TForm1.ListViewCardsButtonClick(const Sender: TObject;
  const AItem: TListItem; const AObject: TListItemSimpleControl);

var
  ImageURL: string;
  CardName: string;
begin
  ImageURL := ShowHighResButton.TagString;
  CardName := 'Sample Card';

  // Create and display the high-res form
  if not Assigned(HighResImageForm) then
    HighResImageForm := THighResImageForm.Create(nil);

  Self.Hide; // Hide the current form (optional)
  HighResImageForm.ShowImage(ImageURL, CardName);

end;

procedure TForm1.ListViewCardsItemClick(const Sender: TObject;
  const AItem: TListViewItem);
// var
// CardDetailsObject: TCardDetailsObject;
begin
  if Assigned(AItem) and Assigned(AItem.TagObject) and
    (AItem.TagObject is TCardDetailsObject) then
  begin
    // Retrieve the card details from the item's TagObject
    // CardDetailsObject := TCardDetailsObject(AItem.TagObject);
    // Call ShowCardDetails with the selected card details
    ShowCardDetails(AItem);
  end
  else
    ShowMessage('No card details are available for this item.');
end;

procedure TForm1.DelayTimerTimer(Sender: TObject);
begin
  if BrIsLoaded then
    Exit;

  TTask.Run(
    procedure
    var
      PopularCards: TStringList;
      RandomCardName: string;
    begin
      PopularCards := TStringList.Create;
      try
        SetupPopularCards(PopularCards);
        if PopularCards.Count > 0 then
          RandomCardName := PopularCards[Random(PopularCards.Count)];
      finally
        PopularCards.Free;
      end;

      TThread.Queue(nil,
        procedure
        begin
          if not RandomCardName.IsEmpty then
            DisplayCardArtworks(RandomCardName);
          BrIsLoaded := True;
          DelayTimer.Enabled := False;
        end);
    end);
end;


function TForm1.IsCardValid(const Card: TCardDetails): Boolean;
begin
  Result := not Card.CardName.IsEmpty and not Card.SFID.IsEmpty;
end;

procedure TForm1.DisplayCardArtworks(const CardName: string);
var
  SelectedSetCode: string;
  SelectedColorCode: string;
  SelectedRareCode: string;

begin
  // Show the progress bar
  ProgressBar1.Visible := True;
  ProgressBar1.Value := 0;

  // Get the selected set code
  if ComboBoxSetCode.Selected.Text = 'All Sets' then
    SelectedSetCode := ''
  else
    SelectedSetCode := ComboBoxSetCode.Selected.Text.Split([' - '])[0];

  // Get the selected rarity
  if ComboBoxRarity.Text = 'All Rarities' then
    SelectedRareCode := ''
  else
    SelectedRareCode := ComboBoxRarity.Text;

  // Get the selected colors
  if ComboBoxColors.Text = 'All Colors' then
    SelectedColorCode := ''
  else
    SelectedColorCode := ComboBoxColors.Text;

  // Call the asynchronous method
  FScryfallAPI.SearchAllCardsAsync(CardName, SelectedSetCode, SelectedRareCode,
    SelectedColorCode, False, False,
    procedure(Success: Boolean; Cards: TArray<TCardDetails>; ErrorMsg: string)
    begin
      TThread.Synchronize(nil,
        procedure
        begin
          // Hide the progress bar when done
          ProgressBar1.Visible := False;

          try
            // Handle errors
            if not Success then
            begin
              ShowMessage('Error searching cards: ' + ErrorMsg);
              Button1.Enabled := True;
              Exit;
            end;

            // Handle empty results
            if Length(Cards) = 0 then
            begin
              ShowMessage('No results found for "' + CardName + '".');
              Button1.Enabled := True;
              Exit;
            end;

            // Handle excessive results
            if Length(Cards) > 800 then
            begin
              ShowMessage('Too many results. Please refine your search.');
              Button1.Enabled := True;
              Exit;
            end;

            // Clear the ListView and internal card list
            ListViewCards.Items.Clear;
            CardDataList.Clear;

            ProgressBar1.Max := Length(Cards);

            // Add valid cards to the ListView and internal card list
            for var CardIndex := 0 to High(Cards) do
            begin
              if IsCardValid(Cards[CardIndex]) then
              begin
                CardDataList.Add(Cards[CardIndex]); // Store valid card details
                AddCardToListView(Cards[CardIndex]); // Add to ListView

                // Update the progress bar
                ProgressBar1.Value := CardIndex + 1;

                // Force the UI to refresh
                Application.ProcessMessages;
              end
              else
              begin
                FScryfallAPI.LogError(Format('Skipping invalid card at index %d: %s',
                  [CardIndex, Cards[CardIndex].CardName]));
              end;
            end;

            // Automatically select and display the first item
            if ListViewCards.Items.Count > 0 then
            begin
              ListViewCards.Selected := ListViewCards.Items[0];
              ShowCardDetails(ListViewCards.Items[0]);
            end;
          finally
            CountLabel.Text := 'Cards Found: ' + ListViewCards.ItemCount.ToString;
          end;
        end);

      // Enable the button
      Button1.Enabled := True;
    end);

  // Ensure the button is enabled in case the async task fails
  Button1.Enabled := True;
end;

procedure TForm1.AddCardToListView(const Card: TCardDetails);
var
  ListViewItem: TListViewItem;
begin
  // Skip invalid cards
  if Card.CardName.IsEmpty or Card.SFID.IsEmpty then
  begin
    FScryfallAPI.LogError('Skipping card: missing "name" or "id".');
    Exit;
  end;

  // Create a new ListView item
  ListViewItem := ListViewCards.Items.Add;

  // Set item properties
  ListViewItem.Text := Card.CardName;
  ListViewItem.Detail := Card.TypeLine;
  ListViewItem.TagObject := TCardDetailsObject.Create(Card);
  // Store the card object
end;

procedure TForm1.ShowCardDetails(Sender: TObject);
var
  SelectedItem: TListViewItem;
  CardDetailsObject: TCardDetailsObject;
  SelectedCard: TCardDetails;
begin
  // Ensure the sender is a TListViewItem
  if Sender is TListViewItem then
  begin
    SelectedItem := TListViewItem(Sender);

    // Check if the TagObject contains card details
    if Assigned(SelectedItem.TagObject) and (SelectedItem.TagObject is TCardDetailsObject) then
    begin
      CardDetailsObject := TCardDetailsObject(SelectedItem.TagObject);
      SelectedCard := CardDetailsObject.CardDetails;
      FCardDetailsObject := CardDetailsObject;

      // Enable the high-res button
      ShowHighResButton.Enabled := SelectedCard.ImageUris.Normal <> '';
      ShowHighResButton.TagString := SelectedCard.ImageUris.Normal;
      CardTitle := SelectedCard.CardName;

      // Display card details immediately without set details
    //  DisplayCardInBrowser(SelectedCard, []);

      // Fetch set details asynchronously
      if not SelectedCard.SetCode.IsEmpty and SelectedCard.SetIconURI.IsEmpty then
      begin
        TTask.Run(
          procedure
          var
            SetDetails: TSetDetails;
          begin
            try
              // Fetch the set details from the API
              SetDetails := FScryfallAPI.GetSetByCode(SelectedCard.SetCode);
              TThread.Synchronize(nil,
                procedure
                begin
                  // Update the card with fetched set details
                  SelectedCard.SetName := SetDetails.Name;
                  SelectedCard.SetIconURI := SetDetails.IconSVGURI;

                  // Refresh the browser with updated set details
                  DisplayCardInBrowser(SelectedCard, []);
                end);
            except
              on E: Exception do
                //LogError('Failed to fetch set details: ' + E.Message);
            end;
          end);
      end;
    end
    else
      ShowMessage('Error: No card details available for this item.');
  end
  else
    ShowMessage('Error: Sender is not a TListViewItem.');
end;

function ReplacePlaceholder(const Template, Placeholder, Value: string): string;
begin
  Result := StringReplace(Template, '{{' + Placeholder + '}}', Value,
    [rfReplaceAll]);
end;

procedure TForm1.DisplayCardInBrowser(const CardDetails: TCardDetails; const Rulings: TArray<TRuling>);
var
  Template: string;
  Replacements: TDictionary<string, string>;
begin
  try
    //Load the HTML template
    Template := LoadTemplate('card_template.html'); // Ensure this file exists and includes proper placeholders

    //  Initialize the replacements dictionary
    Replacements := TDictionary<string, string>.Create;
    try
      // sections of replacements using helper functions
      AddCoreReplacements(Replacements, CardDetails);           // Basic card details
      AddImageReplacements(Replacements, CardDetails);          // Image and layout logic
      AddLegalitiesReplacements(Replacements, CardDetails);     // Legalities table
      AddPricesReplacements(Replacements, CardDetails);         // Prices section
      AddBadgesReplacements(Replacements, CardDetails);         // FullArt, Promo, Reserved badges
      AddKeywordsReplacement(Replacements, CardDetails);        // Keywords section

      //  Perform the replacements in the template
      for var Key in Replacements.Keys do
        Template := Template.Replace(Key, Replacements[Key]);

      //  Display the final HTML in the web browser
      TThread.Queue(nil,
        procedure
        begin
          WebBrowser1.LoadFromStrings(Template, ''); // Load the processed HTML
        end);
    finally
      Replacements.Free; // Free the replacements dictionary
    end;
  except
    on E: Exception do
      ShowMessage('Error displaying card: ' + E.Message);
  end;
end;

procedure TForm1.ShowHighResButtonClick(Sender: TObject);
var
  ImageURL: string;
  CardName: string;
begin
  ImageURL := ShowHighResButton.TagString;
  CardName := 'Sample Card';

  // Create and display the high-res form
  if not Assigned(HighResImageForm) then
    HighResImageForm := THighResImageForm.Create(nil);

  Self.Hide; // Hide the current form (optional)
  HighResImageForm.ShowImage(ImageURL, CardName);
end;

procedure TForm1.Button1Click(Sender: TObject);
begin

  if Trim(Edit1.Text).IsEmpty <> True then
  begin

    DisplayCardArtworks(Trim(Edit1.Text.Trim));
    Button1.Enabled := false;
  end;
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
  if Assigned(FCardDetailsObject) then
  begin
    if DataModule1.CheckCardExists(Trim(FCardDetailsObject.CardDetails.SFID))
    then
      ShowMessage('Card already exists in the database.')
    else
      SaveSelectedCardToDatabase;
  end
  else
    ShowMessage('No card is selected.');
end;

procedure TForm1.ShowCardCollection;
var
  CollectionForm: TCollectionsForm;
begin

  CollectionForm := TCollectionsForm.Create(Self);
  try
    CollectionForm.Show;
  finally
    CollectionForm.Free;
  end;
end;

procedure TForm1.Button5Click(Sender: TObject);
begin
  ShowCardCollection;
  // form2.Show;
end;

procedure TForm1.SaveSelectedCardToDatabase;
var
  ImageStream: TMemoryStream;
  ImageBitmap: TBitmap;
begin
  if not Assigned(FCardDetailsObject) then
  begin
    ShowMessage('No card is selected.');
    Exit;
  end;

  ImageStream := TMemoryStream.Create;
  ImageBitmap := TBitmap.Create;
  try
    // Load the selected card's image from the cache
    if FileExists(GetCachedImagePath(FCardDetailsObject.CardDetails.ImageUris.
      art_crop)) then
    begin
      ImageBitmap.LoadFromFile
        (GetCachedImagePath(FCardDetailsObject.CardDetails.ImageUris.art_crop));

      // Convert Bitmap to stream
      if ImageBitmap.Width > 0 then
      begin
        ImageBitmap.SaveToStream(ImageStream);
        ImageStream.Position := 0;

        // Call the data module to save card details and image
        DataModule1.SaveCardToDatabase(FCardDetailsObject.CardDetails,
          ImageStream, 1);

      end
      else
        ShowMessage('Selected card image is invalid.');
    end
    else
      ShowMessage('Image not found in cache.');
  finally
    ImageStream.Free;
    ImageBitmap.Free;
  end;
end;

initialization

Randomize;

end.

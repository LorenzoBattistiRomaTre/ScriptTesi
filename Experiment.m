
function Experiment(participantName)

% Importa la classe MessageDigest dalla libreria Java per codificare il
% nome del partecipante
import java.security.MessageDigest;

%codifico in SHA-1 il nome del partecipante
str = participantName;
digest = MessageDigest.getInstance('SHA-1');
hash = typecast(digest.digest(uint8(str)), 'uint8');
hashInt = double(hash);
participantName = sprintf('%02x', hashInt);

% Define the display screen
Screen('Preference', 'SkipSyncTests', 1);
screens = Screen('Screens');
screenNumber = max(screens);

%define some variables
fixStartFrame=0.0;
imageStartFrame=0.0;
stimulusDuration = 3; % in seconds
fixDurationBase= 1.5;
c=0; %valore del bit da inviare

% Define black and white
grey = 200;

%Define and open com port
cp= serialport('COM3',9600);

%Define the screen settings
[window, rect] = Screen('OpenWindow', screenNumber, grey);
[~,yPixel]= Screen('WindowSize', window);
[~,~]= RectCenter(rect);

%Priority(MaxPriority(window));

% Define the folder containing the stimuli
stimuliFolder = 'stimuli';
questionFolder = 'question';



% Define the questions and their images
questions = {'Arousal','ArousalTime', 'Valence', 'ValenceTime', 'Rating', 'RatingTime', 'Rewatch', 'Rewatchtime'};
%questionImages = {'arousal.jpeg', 'valence.jpeg', 'rating.jpeg', 'rewatch.jpeg'}; % Da chiamare Arousal.jpg...

% Create the folder for the participant's data
participantFolder = sprintf('%s', participantName);
if ~exist(participantFolder, 'dir')
    mkdir(participantFolder);
end

% Open the csv file to save the participant's answers
csvFile = sprintf('%s/%s.csv', participantFolder, participantName);
fid = fopen(csvFile, 'w');
fprintf(fid, 'Stimulus, Arousal, ArousalTime, Valence, ValenceTime, Likability, LikabilityTime, Rewatch, RewatchTime, Fixframe, ImageFrame, TotalFrame, FixDuration\n');

% Get the list of stimuli
stimuli = dir(sprintf('%s/*.jpg', stimuliFolder));


%randomize the order of stimuli
SeqStimuli = randperm(length(stimuli),length(stimuli));

% Initialize the webcam
cam = webcam('USB Video');
cam.Resolution = '1280x1024';


%pre-processing the fixing image

[fixImage, ~, ~] = imread('neutralImage.jpg');
[sizeY,~,~]= size(fixImage);
scala= (2/3)*yPixel/sizeY;
fix=imresize(fixImage,scala);
TempoDiInizio= GetSecs();
write(cp,1, "uint8");
write(cp,0,"uint8");

%mostro immagine iniziale fino a che non preme invio
image=imread('Initial_image.jpg');
texture = Screen('MakeTexture', window, image);
Screen('DrawTexture', window, texture);
Screen('Flip', window);
input(" ");
% Show each stimulus and ask for the participant's answers
for i = 1:length(stimuli)

    %inserimento pausa a metà sperimentazione
    if i==50
        image= imread('Pause_Image.jpg');
        texture = Screen('MakeTexture', window, image);
        Screen('DrawTexture', window, texture);
        Screen('Flip', window);
        WaitSecs(120);
        image=imread('Initial_image.jpg');
        texture = Screen('MakeTexture', window, image);
        Screen('DrawTexture', window, texture);
        Screen('Flip', window);
        input(" ");
    end

    frame=0.0;
    fixBool=false;
    imageBool=false;

    %Loading Image
    stimulus = stimuli(SeqStimuli(i));
    stimulusFile = sprintf('%s/%s', stimuliFolder, stimulus.name);

    % Record the webcam during the stimulus visualization
    videoFile = sprintf('%s/%s_%s.avi', participantFolder, participantName, stimulus.name);
    writer = VideoWriter(videoFile, 'Uncompressed AVI');
    if startsWith(stimulus.name, 'serene') c=4; end
    if startsWith(stimulus.name, 'inquietanti') c=2; end
    if startsWith(stimulus.name, 'neutre') c=3; end
    %put the image on screen%
    Screen('Flip', window);
    fixDuration= fixDurationBase * unifrnd(0.85, 1.15);
    totalTime=stimulusDuration + fixDuration;
   
    %immagine di sfondo per un tempo randomico tra 0.85 e 1.15
    image=imread('sfondo.jpg');
    texture = Screen('MakeTexture', window, image);
    Screen('DrawTexture', window, texture);
    Screen('Flip', window);
    WaitSecs(unifrnd(0.85, 1.15))
    %start video recording
    open(writer);
    startTime = GetSecs();

    while (GetSecs() - startTime) < totalTime
        if((GetSecs() - startTime< fixDuration) && not(fixBool) )
            fixBool=true;
            fprintf('fix start %d\n', GetSecs() - startTime)
            texture = Screen('MakeTexture', window, fix);
            Screen('DrawTexture', window, texture);
            Screen('Flip', window);
            fprintf('fix flip %d\n', GetSecs() - startTime)
            fixStartFrame = frame;
        end
        if((GetSecs() - startTime >= fixDuration) && not(imageBool))
            imageBool=true;
            fprintf('image renderd %d\n', GetSecs() - startTime)
            [stimolo, ~, ~] = imread(stimulusFile);
            texture = Screen('MakeTexture', window, stimolo);
            Screen('DrawTexture', window, texture);
            Screen('Flip', window);
            fprintf('image fliped %d\n', GetSecs() - startTime)
            imageStartFrame=frame;
            %invio bit seriale di sincornizzazione
            write(cp,c, "uint8");
            pause(0.006);


            write(cp,0,"uint8");
            %fprintf("inviato bit");

        end
        writeVideo(writer,snapshot(cam));

        frame=frame+1;
        [keyIsDown, ~, keyCode] = KbCheck();
        if keyIsDown && keyCode(KbName('ESC'))
            close(writer);
            fclose(fid);
            clear cam;
            % Priority(0);
            Screen('CloseAll');
            return;
        end

    end

    totalFrame=frame;
    fprintf("frame catturati: %d\n", totalFrame);
    fprintf("immagine %d di %d\n", i, length(stimuli));
    %stop filming
    close(writer);


    answers = zeros(1, length(questions));
    %domanda Arousal
    risposta=5;
    startQuestion= GetSecs();

    while true
        % attendi l'input dell'utente
        questionImage = sprintf('arousal_%d.jpg', risposta);
        questionImageFile = sprintf('%s/%s', questionFolder, questionImage);
        [stimolo, ~, ~] = imread(questionImageFile);
        texture = Screen('MakeTexture', window, stimolo);
        Screen('DrawTexture', window, texture);
        Screen('Flip', window);
        FlushEvents('keyDown');
        waitforbuttonpress;
        % ottieni il codice del tasto premuto
        key = get(gcf, 'CurrentCharacter');
        % controlla se il tasto premuto è invio
        if key == char(13)
            % se il tasto premuto è invio, esci dal ciclo
            break;
            % controlla se il tasto premuto è la freccia destra
        elseif key == 29
            % esegui l'azione desiderata per la freccia destra
            risposta= risposta+1;
            if risposta == 10
                risposta = 1;
            end
            % controlla se il tasto premuto è la freccia sinistra
        elseif key == 28
            risposta = risposta-1;
            if risposta == 0
                risposta = 9;
            end
        end
    end
    endQuestion=GetSecs();
    write(cp,5, "uint8");
    pause(0.006);
    write(cp,0,"uint8");
    answers(1)=risposta;
    answers(2)=endQuestion-startQuestion;


    %domanda Valence
    risposta=5;
    startQuestion= GetSecs();
    while true
        % attendi l'input dell'utente
        questionImage = sprintf('valence_%d.jpg',risposta);
        questionImageFile = sprintf('%s/%s', questionFolder, questionImage);
        [stimolo, ~, ~] = imread(questionImageFile);
        texture = Screen('MakeTexture', window, stimolo);
        Screen('DrawTexture', window, texture);
        Screen('Flip', window);
        FlushEvents('keyDown');
        waitforbuttonpress;
        % ottieni il codice del tasto premuto
        key = get(gcf, 'CurrentCharacter');
        % controlla se il tasto premuto è invio
        if key == char(13)
            % se il tasto premuto è invio, esci dal ciclo
            break;
            % controlla se il tasto premuto è la freccia destra
        elseif key == 29
            % esegui l'azione desiderata per la freccia destra
            risposta= risposta+1;
            if risposta == 10
                risposta = 1;
            end
            % controlla se il tasto premuto è la freccia sinistra
        elseif key == 28
            risposta = risposta-1;
            if risposta == 0
                risposta = 9;
            end
        end
    end
    endQuestion=GetSecs();
    write(cp,5, "uint8");
    pause(0.006);
    write(cp,0,"uint8");
    answers(3)=risposta;
    answers(4)=endQuestion-startQuestion;

    %domanda Rating
    risposta=3;
    startQuestion= GetSecs();
    while true
        % attendi l'input dell'utente
        questionImage = sprintf('rating_%d.jpg',risposta);
        questionImageFile = sprintf('%s/%s', questionFolder, questionImage);
        [stimolo, ~, ~] = imread(questionImageFile);
        texture = Screen('MakeTexture', window, stimolo);
        Screen('DrawTexture', window, texture);
        Screen('Flip', window);
        FlushEvents('keyDown');
        waitforbuttonpress;
        % ottieni il codice del tasto premuto
        key = get(gcf, 'CurrentCharacter');
        % controlla se il tasto premuto è invio
        if key == char(13)
            % se il tasto premuto è invio, esci dal ciclo
            break;
            % controlla se il tasto premuto è la freccia destra
        elseif key == 29
            % esegui l'azione desiderata per la freccia destra
            risposta= risposta+1;
            if risposta == 6
                risposta = 1;
            end
            % controlla se il tasto premuto è la freccia sinistra
        elseif key == 28
            risposta = risposta-1;
            if risposta == 0
                risposta = 5;
            end
        end
    end
    endQuestion=GetSecs();
    write(cp,5, "uint8");
    pause(0.006);
    write(cp,0,"uint8");
    answers(5)=risposta;
    answers(6)=endQuestion-startQuestion;

    %domanda rewatch
    risposta=2;
    startQuestion= GetSecs();
    while true
        % attendi l'input dell'utente
        questionImage = sprintf('rewatch_%d.jpg',risposta);
        questionImageFile = sprintf('%s/%s', questionFolder, questionImage);
        [stimolo, ~, ~] = imread(questionImageFile);
        texture = Screen('MakeTexture', window, stimolo);
        Screen('DrawTexture', window, texture);
        Screen('Flip', window);
        FlushEvents('keyDown');
        waitforbuttonpress;
        % ottieni il codice del tasto premuto
        key = get(gcf, 'CurrentCharacter');
        % controlla se il tasto premuto è invio
        if key == char(13)
            % se il tasto premuto è invio, esci dal ciclo
            break;
            % controlla se il tasto premuto è la freccia destra
        elseif key == 29
            % esegui l'azione desiderata per la freccia destra
            risposta= risposta+1;
            if risposta == 4
                risposta = 1;
            end
            % controlla se il tasto premuto è la freccia sinistra
        elseif key == 28
            risposta = risposta-1;
            if risposta == 0
                risposta = 3;
            end
        end
    end

    endQuestion=GetSecs();
    write(cp,5, "uint8");
    pause(0.006);
    write(cp,0,"uint8");
    answers(7)=risposta;
    answers(8)=endQuestion-startQuestion;

    % Save the participant's answers in the csv file
    fprintf(fid, '%s, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d\n', stimulus.name, answers(1), answers(2), answers(3), answers(4), answers(5), answers(6), answers(7), answers(8), fixStartFrame, imageStartFrame, fixDuration);

end

tempoDiFine=GetSecs();
write(cp,1, "uint8");
write(cp,0,"uint8");
% Close the csv file and the display screens
fclose(fid);
clear cam;
%Priority(0);
Screen('CloseAll');
tempoTotale=tempoDiFine-TempoDiInizio;
fprintf('tempo totale %d\n', tempoTotale);
end
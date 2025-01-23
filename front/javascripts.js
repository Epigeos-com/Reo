window.IndexRazor = { // This is needed to run non-static C# scripts
    IndexReference: null,
    SaveComponent: function (componentReference) {
        IndexRazor.IndexReference = componentReference;
    },
    SaveSettings: function () {
        IndexRazor.IndexReference.invokeMethodAsync('SaveSettings', true);
        IndexRazor.IndexReference.invokeMethodAsync('StateHasChanged');
    },
    StateHasChanged: function () {
        IndexRazor.IndexReference.invokeMethodAsync('StateHasChanged');
    }
}
function CloseEventUI() {
    DotNet.invokeMethodAsync('Calendar', 'CloseEventUI'); // Index.razor
    IndexRazor.StateHasChanged();
}
function ChangeDateBy1Unit(isForward) {
    DotNet.invokeMethodAsync('Calendar', 'ChangeDateBy1Unit', isForward); // Index.razor
    IndexRazor.StateHasChanged();
}
function ToggleDay(date = null) {
    DotNet.invokeMethodAsync('Calendar', 'ToggleDay', date); // Index.razor
    IndexRazor.StateHasChanged();
}
function ShowSunPosition() {
    DotNet.invokeMethodAsync('Calendar', 'ShowSunPosition'); // Index.razor
    IndexRazor.StateHasChanged();
}

document.onkeydown = function (evt) {
    evt = evt || window.event;
    if (evt.key == "Escape") {
        OnEsc();
    } else if (evt.key == "F11") {
        DotNet.invokeMethodAsync('Calendar', 'ToggleFullScreen') // MauiProgram
    } else if (!IsAnyDialogOpen()) {
        if (evt.key == "ArrowLeft") {
            ChangeDateBy1Unit(false);
        } else if (evt.key == "ArrowRight") {
            ChangeDateBy1Unit(true);
        }
    }
}
function OnEsc() {
    let additional = document.getElementById("additionalDialog");
    let info = document.getElementById("infoDialog");
    let settings = document.getElementById("settingsDialog");
    let event = document.getElementById("eventDialog");
    let goto = document.getElementById("gotoDialog");
    if (IsAnyDialogOpen()) {
        additional.close();
        info.close();
        if (settings.open != "") {
            IndexRazor.SaveSettings();
            settings.close();
        }
        if (event.open != "") {
            CloseEventUI();
            event.close();
        }
        goto.close();
        document.getElementById('pageContent').classList.remove('blur');
    } else {
        ToggleDay();
    }
}
function ToggleDialog(id, scrollTo) {
    let dialog = document.getElementById(id);
    if (!IsAnyDialogOpen()) {
        dialog.show();
        document.getElementById('pageContent').classList.add('blur');
    } else if (dialog.open != "") {
        dialog.close();
        document.getElementById('pageContent').classList.remove('blur');
        return;
    }

    if (scrollTo) {
        document.getElementById(scrollTo + 'Header').scrollIntoView()
    }
}
function ScrollTo(title) {
    document.getElementById(title + 'Header').scrollIntoView({ behavior: "smooth"})
}
function IsAnyDialogOpen() {
    return !(document.getElementById("additionalDialog").open == "" && document.getElementById("infoDialog").open == "" && document.getElementById("settingsDialog").open == "" && document.getElementById("eventDialog").open == "" && document.getElementById("gotoDialog").open == "");
}

function EditEventOpenUI(ev) {
    DotNet.invokeMethodAsync('Calendar', 'EditEventOpenUI', ev); // Index.razor
    ToggleDialog('eventDialog');
    IndexRazor.StateHasChanged();
}


// Android gestures
document.addEventListener('touchstart', OnTouchStart, false);
document.addEventListener('touchmove', OnTouchMove, false);
let beginningX = null;
let beginningY = null;

function OnTouchStart(evt) {
    const touch = evt.touches[0];
    beginningX = touch.clientX;
    beginningY = touch.clientY;
};
function OnTouchMove(evt) {
    if (!beginningX) return;

    if (!IsAnyDialogOpen()) {
        const touch = evt.touches[0];
        let finalX = touch.clientX;
        let finalY = touch.clientY;
        if (Math.abs(beginningX - finalX) > Math.abs(beginningY - finalY)) {
            if (beginningX - finalX > 0) {
                ChangeDateBy1Unit(true);
            } else {
                ChangeDateBy1Unit(false);
            }
        }
    }
    beginningX = null;
};



function ShowAdditionalDialog(content) {
    document.getElementById('additionalDialogContent').innerHTML = content;
    ToggleDialog('additionalDialog');
}
function ShowVersionDialog(currentVersion, latestVersion, OS) {
    ShowAdditionalDialog(`
    <p class="Piazzolla header1">Update available</p>
    <p>Visit <a href="https://calendar.epigeos.com/downloads?auto=latest${OS}">https://calendar.epigeos.com/downloads</a> to download new version</p>
    <p>Your current version: ${currentVersion}</p>
    <p>Latest version: ${latestVersion}</p>`);
}
function ShowPollDialog(poll) {
    document.getElementById('additionalDialogContent').innerHTML = `
    <p class="Piazzolla header1">Next calendar poll</p>
    <p>Visit <a href="https://calendar.epigeos.com/info?s=poll">https://calendar.epigeos.com/info</a> for more information about each calendar</p>`;
    poll.split('\n').forEach(element => {
        document.getElementById('additionalDialogContent').innerHTML += `<input type="button" value="${element}" onclick="javascript:SendPoll('${element}')">`;
    })
    document.getElementById('additionalDialogContent').innerHTML += `<input type="button" value="I don't want to answer" onclick="javascript:SendPoll('')">`;

}
function SendPoll(option) {
    ToggleDialog('additionalDialog');
    DotNet.invokeMethodAsync('Calendar', 'SendPoll', option); // Index
}

function SetLightMode(light) {
    if (light) {
        document.body.classList.add('light');
    } else {
        document.body.classList.remove('light');
    }
}
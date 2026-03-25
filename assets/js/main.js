document.addEventListener('DOMContentLoaded', function () {
    var levelBars = document.querySelectorAll('.level-bar-inner');
    var validLevelPattern = /^(100|[1-9]?\d)%$/;

    levelBars.forEach(function (levelBar) {
        var level = levelBar.getAttribute('data-level');

        if (!validLevelPattern.test(level)) {
            return;
        }

        window.requestAnimationFrame(function () {
            levelBar.style.width = level;
        });
    });
});

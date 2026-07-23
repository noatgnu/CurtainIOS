if (typeof Plotly === 'undefined') {
    console.error('Plotly.js failed to load');
    document.getElementById('loading').style.display = 'none';
    document.getElementById('error').style.display = 'block';
} else {
    Plotly.setPlotConfig({
        displayModeBar: true,
        displaylogo: false,
        modeBarButtonsToRemove: ['sendDataToCloud', 'editInChartStudio']
    });

    const plotData = {{PLOT_DATA}};

    document.addEventListener('DOMContentLoaded', function() {
        try {
            document.getElementById('loading').style.display = 'none';
            document.getElementById('error').style.display = 'none';
            document.getElementById('plot').style.display = 'block';

            Plotly.newPlot('plot', plotData.data, plotData.layout, plotData.config)
                .then(() => {
                    console.log('{{CHART_TITLE}} loaded successfully');
                    // Cache SVG via Plotly.toImage — Plotly handles full style serialization
                    try {
                        var plotDiv = document.getElementById('plot');
                        if (plotDiv) {
                            var bgColor = window.getComputedStyle(document.body).backgroundColor || '#ffffff';
                            Plotly.toImage(plotDiv, {
                                format: 'svg',
                                setBackground: bgColor
                            }).then(function(dataURL) {
                                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.svgCached) {
                                    window.webkit.messageHandlers.svgCached.postMessage(dataURL);
                                }
                            }).catch(function(e) { console.error('SVG cache failed:', e); });
                        }
                    } catch(e) { console.error('SVG cache error:', e); }
                })
                .catch(error => {
                    console.error('Error creating chart:', error);
                    document.getElementById('plot').style.display = 'none';
                    document.getElementById('error').style.display = 'flex';
                });
        } catch (error) {
            console.error('Error in initialization:', error);
            document.getElementById('loading').style.display = 'none';
            document.getElementById('error').style.display = 'flex';
        }
    });
}

window.ProteinChart = {
    exportPlot: function(format, filename, width, height) {
        var plotDiv = document.getElementById('plot');
        if (!plotDiv) return;
        Plotly.toImage(plotDiv, {
            format: format || 'png',
            width: width || 1200,
            height: height || 800
        }).then(function(dataUrl) {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.exportHandler) {
                window.webkit.messageHandlers.exportHandler.postMessage(JSON.stringify({
                    format: format || 'png',
                    filename: filename || 'protein_chart',
                    dataURL: dataUrl
                }));
            }
        }).catch(function(error) {
            console.error('Export failed:', error);
        });
    }
};

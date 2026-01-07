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

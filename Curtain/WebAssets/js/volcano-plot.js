// Check if Plotly loaded successfully
if (typeof Plotly === 'undefined') {
    console.error('Plotly.js failed to load');
    document.getElementById('loading').style.display = 'none';
    document.getElementById('error').style.display = 'block';
    document.getElementById('error').innerHTML = '<div><h3>Plot Library Error</h3><p>Unable to load plotting library. Please try again.</p></div>';
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.plotError) {
        window.webkit.messageHandlers.plotError.postMessage('Plotly.js failed to load');
    }
} else {
    Plotly.setPlotConfig({
        displayModeBar: true,
        displaylogo: false,
        modeBarButtonsToRemove: ['sendDataToCloud', 'editInChartStudio']
    });

    const plotData = {{PLOT_DATA}};
    const editMode = {{EDIT_MODE}};

    let currentPlot = null;
    let selectedPoints = [];
    let annotations = plotData.layout.annotations || [];

    const annotationMap = new Map();

    console.log('Initial annotations from plotData:', annotations);
    console.log('Number of annotations:', annotations.length);

    window.VolcanoPlot = {
        initialize: function() {
            try {
                document.getElementById('loading').style.display = 'none';
                document.getElementById('error').style.display = 'none';
                document.getElementById('plot').style.display = 'block';

                Plotly.newPlot('plot', plotData.data, plotData.layout, plotData.config)
                    .then(() => {
                        currentPlot = document.getElementById('plot');
                        this.initializeAnnotationMap();
                        this.setupEventHandlers();
                        this.notifyReady();
                    })
                    .catch(error => {
                        console.error('Error creating volcano plot:', error);
                        this.showError('Failed to create volcano plot: ' + error.message);
                    });
            } catch (error) {
                console.error('Error in initialize:', error);
                this.showError('JavaScript error: ' + error.message);
            }
        },

        getPlotDimensions: function() {
            if (!currentPlot || !currentPlot._fullLayout) {
                console.log('📊 No plot or layout available');
                return null;
            }

            const layout = currentPlot._fullLayout;
            const plotDiv = currentPlot;

            const body = document.body || document.documentElement;
            const html = document.documentElement;

            const webViewRect = body.getBoundingClientRect();
            const webViewScrollLeft = html.scrollLeft || body.scrollLeft || 0;
            const webViewScrollTop = html.scrollTop || body.scrollTop || 0;

            console.log('🌐 WebView position in parent view:', {
                left: webViewRect.left,
                top: webViewRect.top,
                width: webViewRect.width,
                height: webViewRect.height,
                scrollLeft: webViewScrollLeft,
                scrollTop: webViewScrollTop
            });

            const plotElementRect = plotDiv.getBoundingClientRect();
            const plotElementOffsetX = plotElementRect.left - webViewRect.left + webViewScrollLeft;
            const plotElementOffsetY = plotElementRect.top - webViewRect.top + webViewScrollTop;

            console.log('📈 Plot element position in WebView:', {
                offsetX: plotElementOffsetX,
                offsetY: plotElementOffsetY,
                width: plotElementRect.width,
                height: plotElementRect.height
            });

            const xaxis = layout.xaxis;
            const yaxis = layout.yaxis;

            if (!xaxis || !yaxis || !xaxis.range || !yaxis.range) {
                console.log('📊 No axis information available');
                return null;
            }

            console.log('📊 Axis ranges - X:', xaxis.range, 'Y:', yaxis.range);

            try {
                const margin = layout.margin || {};
                const marginLeft = margin.l || 80;
                const marginTop = margin.t || 100;
                const marginRight = margin.r || 80;
                const marginBottom = margin.b || 80;

                console.log('📊 Plotly margins:', margin);
                console.log('📊 Calculated margins - L:', marginLeft, 'T:', marginTop, 'R:', marginRight, 'B:', marginBottom);

                const xMin = xaxis.range[0];
                const xMax = xaxis.range[1];
                const yMin = yaxis.range[0];
                const yMax = yaxis.range[1];

                const plotRelativeTopLeft = {
                    x: xaxis.l2p(xMin),
                    y: yaxis.l2p(yMax)
                };
                const plotRelativeBottomRight = {
                    x: xaxis.l2p(xMax),
                    y: yaxis.l2p(yMin)
                };

                console.log('📊 Plot-relative coordinates within element - TopLeft:', plotRelativeTopLeft, 'BottomRight:', plotRelativeBottomRight);

                const plotAreaLeft = marginLeft + plotRelativeTopLeft.x;
                const plotAreaTop = marginTop + plotRelativeTopLeft.y;
                const plotAreaRight = marginLeft + plotRelativeBottomRight.x;
                const plotAreaBottom = marginTop + plotRelativeBottomRight.y;

                const finalPlotLeft = webViewRect.left + plotElementOffsetX + plotAreaLeft;
                const finalPlotTop = webViewRect.top + plotElementOffsetY + plotAreaTop;
                const finalPlotRight = webViewRect.left + plotElementOffsetX + plotAreaRight;
                const finalPlotBottom = webViewRect.top + plotElementOffsetY + plotAreaBottom;

                console.log('📊 Final plot boundaries in parent view coordinates:');
                console.log('   L=' + finalPlotLeft + ', T=' + finalPlotTop + ', R=' + finalPlotRight + ', B=' + finalPlotBottom);

                return {
                    plotLeft: finalPlotLeft,
                    plotRight: finalPlotRight,
                    plotTop: finalPlotTop,
                    plotBottom: finalPlotBottom,

                    webView: {
                        left: webViewRect.left,
                        top: webViewRect.top,
                        width: webViewRect.width,
                        height: webViewRect.height
                    },
                    plotElement: {
                        offsetX: plotElementOffsetX,
                        offsetY: plotElementOffsetY,
                        width: plotElementRect.width,
                        height: plotElementRect.height
                    },
                    plotArea: {
                        left: plotAreaLeft,
                        top: plotAreaTop,
                        right: plotAreaRight,
                        bottom: plotAreaBottom,
                        width: plotAreaRight - plotAreaLeft,
                        height: plotAreaBottom - plotAreaTop
                    },

                    fullWidth: plotDiv.offsetWidth,
                    fullHeight: plotDiv.offsetHeight,

                    xRange: xaxis.range,
                    yRange: yaxis.range,

                    method: 'complete_hierarchy_l2p',
                    hasL2P: !!(xaxis.l2p && yaxis.l2p),
                    coordinateHierarchy: 'webView->plotElement->plotArea'
                };

            } catch (error) {
                console.log('📊 Error using Plotly l2p functions:', error);

                const xDomain = xaxis.domain || [0, 1];
                const yDomain = yaxis.domain || [0, 1];

                const plotAreaLeft = xDomain[0] * plotDiv.offsetWidth;
                const plotAreaRight = xDomain[1] * plotDiv.offsetWidth;
                const plotAreaTop = (1 - yDomain[1]) * plotDiv.offsetHeight;
                const plotAreaBottom = (1 - yDomain[0]) * plotDiv.offsetHeight;

                const finalPlotLeft = webViewRect.left + plotElementOffsetX + plotAreaLeft;
                const finalPlotTop = webViewRect.top + plotElementOffsetY + plotAreaTop;
                const finalPlotRight = webViewRect.left + plotElementOffsetX + plotAreaRight;
                const finalPlotBottom = webViewRect.top + plotElementOffsetY + plotAreaBottom;

                console.log('📊 Using domain fallback with complete hierarchy - xDomain:', xDomain, 'yDomain:', yDomain);
                console.log('📊 Domain-based boundaries: L=' + finalPlotLeft + ', T=' + finalPlotTop + ', R=' + finalPlotRight + ', B=' + finalPlotBottom);

                return {
                    plotLeft: finalPlotLeft,
                    plotRight: finalPlotRight,
                    plotTop: finalPlotTop,
                    plotBottom: finalPlotBottom,

                    webView: {
                        left: webViewRect.left,
                        top: webViewRect.top,
                        width: webViewRect.width,
                        height: webViewRect.height
                    },
                    plotElement: {
                        offsetX: plotElementOffsetX,
                        offsetY: plotElementOffsetY,
                        width: plotElementRect.width,
                        height: plotElementRect.height
                    },
                    plotArea: {
                        left: plotAreaLeft,
                        top: plotAreaTop,
                        right: plotAreaRight,
                        bottom: plotAreaBottom,
                        width: plotAreaRight - plotAreaLeft,
                        height: plotAreaBottom - plotAreaTop
                    },

                    fullWidth: plotDiv.offsetWidth,
                    fullHeight: plotDiv.offsetHeight,
                    xRange: xaxis.range,
                    yRange: yaxis.range,
                    method: 'complete_hierarchy_domain_fallback',
                    hasL2P: false,
                    coordinateHierarchy: 'webView->plotElement->plotArea'
                };
            }
        },

        convertPlotToScreen: function(x, y) {
            if (!currentPlot || !currentPlot._fullLayout) {
                console.log('📊 convertPlotToScreen: No plot available');
                return null;
            }

            const dims = this.getPlotDimensions();
            if (!dims) {
                console.log('📊 convertPlotToScreen: No plot dimensions available');
                return null;
            }

            const layout = currentPlot._fullLayout;
            const xaxis = layout.xaxis;
            const yaxis = layout.yaxis;

            if (!xaxis || !yaxis) {
                console.log('📊 convertPlotToScreen: No axis available');
                return null;
            }

            try {
                const plotRelativeX = xaxis.l2p(x);
                const plotRelativeY = yaxis.l2p(y);

                const margin = layout.margin || {};
                const marginLeft = margin.l || 80;
                const marginTop = margin.t || 100;

                const plotElementX = marginLeft + plotRelativeX;
                const plotElementY = marginTop + plotRelativeY;

                const finalScreenX = dims.webView.left + dims.plotElement.offsetX + plotElementX;
                const finalScreenY = dims.webView.top + dims.plotElement.offsetY + plotElementY;

                console.log('📊 convertPlotToScreen complete hierarchy:');
                console.log('   Plot coords: (' + x + ',' + y + ')');
                console.log('   Plot-relative: (' + plotRelativeX + ',' + plotRelativeY + ')');
                console.log('   Plot element: (' + plotElementX + ',' + plotElementY + ')');
                console.log('   WebView offset: (' + dims.webView.left + ',' + dims.webView.top + ')');
                console.log('   Element offset: (' + dims.plotElement.offsetX + ',' + dims.plotElement.offsetY + ')');
                console.log('   Final screen: (' + finalScreenX + ',' + finalScreenY + ')');

                return {
                    x: finalScreenX,
                    y: finalScreenY,
                    hierarchy: {
                        plotRelative: { x: plotRelativeX, y: plotRelativeY },
                        plotElement: { x: plotElementX, y: plotElementY },
                        webViewOffset: { x: dims.webView.left, y: dims.webView.top },
                        elementOffset: { x: dims.plotElement.offsetX, y: dims.plotElement.offsetY }
                    }
                };

            } catch (error) {
                console.log('📊 Error in convertPlotToScreen l2p, using fallback:', error);

                if (!dims.plotArea) {
                    console.log('📊 No plot area information for fallback');
                    return null;
                }

                const plotAreaWidth = dims.plotArea.width;
                const plotAreaHeight = dims.plotArea.height;

                const normalizedX = (x - dims.xRange[0]) / (dims.xRange[1] - dims.xRange[0]);
                const normalizedY = (dims.yRange[1] - y) / (dims.yRange[1] - dims.yRange[0]);

                const plotAreaX = normalizedX * plotAreaWidth;
                const plotAreaY = normalizedY * plotAreaHeight;

                const finalScreenX = dims.webView.left + dims.plotElement.offsetX + dims.plotArea.left + plotAreaX;
                const finalScreenY = dims.webView.top + dims.plotElement.offsetY + dims.plotArea.top + plotAreaY;

                console.log('📊 convertPlotToScreen fallback with complete hierarchy:');
                console.log('   Plot coords: (' + x + ',' + y + ') -> normalized: (' + normalizedX + ',' + normalizedY + ')');
                console.log('   Plot area: (' + plotAreaX + ',' + plotAreaY + ')');
                console.log('   Final screen: (' + finalScreenX + ',' + finalScreenY + ')');

                return {
                    x: finalScreenX,
                    y: finalScreenY,
                    method: 'fallback_with_hierarchy'
                };
            }
        },

        initializeAnnotationMap: function() {
            annotationMap.clear();

            if (currentPlot && currentPlot.layout && currentPlot.layout.annotations) {
                annotations = currentPlot.layout.annotations;
                console.log('Updated annotations from live plot:', annotations.length, 'annotations');
            }

            const dims = this.getPlotDimensions();
            console.log('Plot dimensions:', dims);

            annotations.forEach((annotation, index) => {
                console.log('Annotation', index, ':', JSON.stringify(annotation, null, 2));
            });

            annotations.forEach((annotation, index) => {
                const annotationInfo = {
                    annotation: annotation,
                    index: index
                };

                let identifier = null;
                if (annotation.title) {
                    identifier = annotation.title;
                    console.log('Mapped annotation by title:', identifier, 'at index', index);
                } else if (annotation.text) {
                    identifier = annotation.text.replace(/<[^>]*>/g, '');
                    console.log('Mapped annotation by text:', identifier, 'at index', index);
                } else if (annotation.id) {
                    identifier = annotation.id;
                    console.log('Mapped annotation by ID:', identifier, 'at index', index);
                }

                if (identifier) {
                    annotationMap.set(identifier, annotationInfo);
                } else {
                    console.warn('No identifier found for annotation at index', index);
                }
            });

            console.log('Annotation map initialized with', annotationMap.size, 'entries');
            console.log('Map keys:', Array.from(annotationMap.keys()));
        },

        setupEventHandlers: function() {
            if (!currentPlot) return;

            currentPlot.on('plotly_click', (data) => {
                if (data.points && data.points.length > 0) {
                    const point = data.points[0];
                    const clickData = {
                        proteinId: point.customdata.id,
                        id: point.customdata.id,
                        primaryID: point.customdata.id,
                        proteinName: point.customdata.gene,
                        log2FC: point.x,
                        pValue: point.customdata.pValue,
                        x: point.x,
                        y: point.y,
                        screenX: data.event.clientX,
                        screenY: data.event.clientY
                    };

                    console.log('Point clicked:', clickData);
                    this.notifyPointClicked(clickData);
                }
            });

            if (editMode) {
                this.enableAnnotationEditing();
            }

            currentPlot.on('plotly_hover', (data) => {
                if (data.points && data.points.length > 0) {
                    const point = data.points[0];
                    this.notifyPointHovered(point.customdata);
                }
            });
        },

        enableAnnotationEditing: function() {
        },

        updatePlot: function(newData) {
            try {
                if (currentPlot) {
                    Plotly.react(currentPlot, newData.data, newData.layout, newData.config)
                        .then(() => {
                            this.notifyUpdated();
                        })
                        .catch(error => {
                            console.error('Error updating plot:', error);
                            this.showError('Failed to update plot: ' + error.message);
                        });
                }
            } catch (error) {
                console.error('Error in updatePlot:', error);
                this.showError('JavaScript error: ' + error.message);
            }
        },

        addAnnotation: function(annotation) {
            annotations.push(annotation);
            this.updateAnnotations();
        },

        updateAnnotations: function() {
            if (currentPlot) {
                const update = { 'annotations': annotations };
                Plotly.relayout(currentPlot, update);
            }
        },

        updateAnnotationPosition: function(annotationTitle, ax, ay) {
            if (!currentPlot) {
                console.error('No current plot available');
                return;
            }

            const annotationInfo = annotationMap.get(annotationTitle);

            if (annotationInfo) {
                annotationInfo.annotation.ax = ax;
                annotationInfo.annotation.ay = ay;

                const update = {
                    ['annotations[' + annotationInfo.index + '].ax']: ax,
                    ['annotations[' + annotationInfo.index + '].ay']: ay
                };

                try {
                    Plotly.relayout(currentPlot, update);
                } catch (error) {
                    console.error('Plotly.relayout failed:', error);
                }
            } else {
                for (let [key, info] of annotationMap.entries()) {
                    if (info.annotation.text && info.annotation.text.includes(annotationTitle)) {
                        return this.updateAnnotationPosition(key, ax, ay);
                    }
                }

                console.warn('No annotation found for title:', annotationTitle);
            }
        },

        updateAnnotationPositions: function(updates) {
            if (!currentPlot || !updates || updates.length === 0) return;

            const batchUpdate = {};
            let hasChanges = false;

            for (const update of updates) {
                const annotationInfo = annotationMap.get(update.title);

                if (annotationInfo) {
                    annotationInfo.annotation.ax = update.ax;
                    annotationInfo.annotation.ay = update.ay;

                    batchUpdate['annotations[' + annotationInfo.index + '].ax'] = update.ax;
                    batchUpdate['annotations[' + annotationInfo.index + '].ay'] = update.ay;
                    hasChanges = true;
                }
            }

            if (hasChanges) {
                Plotly.relayout(currentPlot, batchUpdate);
            }
        },

        showError: function(message) {
            document.getElementById('loading').style.display = 'none';
            document.getElementById('plot').style.display = 'none';
            const errorDiv = document.getElementById('error');
            errorDiv.innerHTML = '<div><h3>Volcano Plot Error</h3><p>' + message + '</p></div>';
            errorDiv.style.display = 'flex';
            this.notifyError(message);
        },

        notifyReady: function() {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.plotReady) {
                window.webkit.messageHandlers.plotReady.postMessage('ready');
            }
        },

        notifyPointClicked: function(pointData) {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.pointClicked) {
                window.webkit.messageHandlers.pointClicked.postMessage(JSON.stringify(pointData));
            }
        },

        notifyPointHovered: function(pointData) {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.pointHovered) {
                window.webkit.messageHandlers.pointHovered.postMessage(JSON.stringify(pointData));
            }
        },

        notifyUpdated: function() {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.plotUpdated) {
                window.webkit.messageHandlers.plotUpdated.postMessage('updated');
            }
        },

        notifyError: function(message) {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.plotError) {
                window.webkit.messageHandlers.plotError.postMessage(message);
            }
        },

        sendPlotDimensions: function() {
            const dims = this.getPlotDimensions();
            if (dims && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.plotDimensions) {
                window.webkit.messageHandlers.plotDimensions.postMessage(JSON.stringify(dims));
            }
        },

        convertAndSendCoordinates: function(annotations) {
            const results = [];
            const dims = this.getPlotDimensions();

            console.log('🎯 convertAndSendCoordinates called with', annotations.length, 'annotations');
            console.log('🎯 Plot dimensions:', dims);

            if (dims) {
                for (const annotation of annotations) {
                    const screenPos = this.convertPlotToScreen(annotation.x, annotation.y);
                    console.log('🎯 Annotation:', annotation.id || annotation.title,
                               'Data coords:', annotation.x, annotation.y,
                               'Screen coords:', screenPos?.x, screenPos?.y,
                               'Offsets:', annotation.ax || 0, annotation.ay || 0);

                    if (screenPos) {
                        results.push({
                            id: annotation.id || annotation.title,
                            plotX: annotation.x,
                            plotY: annotation.y,
                            screenX: screenPos.x,
                            screenY: screenPos.y,
                            ax: annotation.ax || 0,
                            ay: annotation.ay || 0
                        });
                    }
                }
            }

            console.log('🎯 Sending coordinate results:', results);

            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.annotationCoordinates) {
                window.webkit.messageHandlers.annotationCoordinates.postMessage(JSON.stringify(results));
            }
        }
    };

    document.addEventListener('DOMContentLoaded', function() {
        window.VolcanoPlot.initialize();
    });
}

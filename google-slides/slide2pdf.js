/*
 * Description
 *     Allows Google Slides exporting as PDF file.
 * Usage
 *     slide2pdf.js [url] [output file].pdf
 */

const args = process.argv;
const puppeteer = require("puppeteer");
const fs = require("fs");
const { PDFDocument } = require("pdf-lib");
const sleep = ms => new Promise(res => setTimeout(res, ms));

// CLI parameters
let URL = args.slice(2);
let OUTPUT_FILE = args.slice(3);

// CLI Parameters validation
if (URL.length == 0) {/* #< */
    process.stdout.write("[Error] URL not given!\n");
    process.exit(1);
}
URL = URL[0];
if (OUTPUT_FILE.length == 0) {
    process.stdout.write("[Error] output pdf file name not given!\n");
    process.exit(1);
}
OUTPUT_FILE = OUTPUT_FILE[0];
// Fixs output file pdf extension
if (!OUTPUT_FILE.includes(".pdf"))
    OUTPUT_FILE += ".pdf";
/* #> */

/**
 * Retrieves a full date formated as 'yyyy_mm_dd_hh_mi_ss'
 */
function get_str_date() {
    const now = new Date();/* #< */
    const yyyy = now.getFullYear();
    const mm = String(now.getMonth() +1).padStart(2, '0');
    const dd = String(now.getDate()).padStart(2, '0');
    const hh = String(now.getHours()).padStart(2, '0');
    const mi = String(now.getMinutes()).padStart(2, '0');
    const ss = String(now.getSeconds()).padStart(2, '0');
    return `${yyyy}_${mm}_${dd}_${hh}_${mi}_${ss}`;/* #> */
}

// CONFIGS
const DATE_MARK = get_str_date();
const WIDTH = 1610;
const HEIGHT = 902
const SLIDES_FOLDER = `./slides_${DATE_MARK}/`;
const SLIDE_NAME = "i.png";
const MS_BETWEEN_SLIDES = 1000;

// Set date mark to output file
// OUTPUT_FILE = `${DATE_MARK}_${OUTPUT_FILE}`;

(async () => {
    console.log("[Info] Initializing browser...");/* #< */
    const browser = await puppeteer.launch({headless: "new"});/* #< */
    const page = await browser.newPage();
    await page.setViewport({width: WIDTH, height: HEIGHT});/* #> */

    console.log("[Info] Loading presentation...");
    await page.goto(URL, {waitUntil: 'networkidle2'});

    console.log("[Info] Reading slides number...");
    const slides = await page.evaluate(() => {/* #< */
        return document.body.innerHTML.match(/SK_modelChunkParseStart =/g).length;
    });/* #> */

    // Hide navbar & fits slides into viewport
    await page.evaluate(() => {/* #< */
        document.querySelector(".punch-viewer-navbar").style.display = "none";
        let viewer = document.querySelector(".sketchyViewerContentFixed");
        // fixed values for now 1603x902
        viewer.style.left = "0";
        viewer.style.width = "1608px";
        viewer.style.height = "902px";
        viewer.style.marginBottom = "0px !important";
    });/* #> */

    // Create output folder
    fs.mkdirSync(SLIDES_FOLDER);

    // Captures extraction
    for (let i = 1; i <= slides; i++) {/* #< */
        let slide_i = String(i).padStart(3, '0');
        let item_name = SLIDES_FOLDER + SLIDE_NAME.replace('i', slide_i);
        console.log(`[Info] Extracting slide ${slide_i}: ${item_name}`);

        await page.screenshot({path: item_name});
        await page.keyboard.press("ArrowRight");
        await sleep(MS_BETWEEN_SLIDES);
    }/* #> */

    await browser.close();

    // Converts all img into single pdf file
    console.log(`[Info] Exporting as ${OUTPUT_FILE}...`);/* #< */
    const img_slides = fs.readdirSync(SLIDES_FOLDER)
        .filter(f => f.endsWith(".png"))
        .sort();/* #> */

    // Create pdf document
    const pdf_doc = await PDFDocument.create();/* #< */
    for (const slide of img_slides) {
        const slide_path = `${SLIDES_FOLDER}${slide}`;
        console.log(`[Info] Adding '${slide_path}'...`);
        const fimg = fs.readFileSync(slide_path);
        // Create img embed
        const embed_img = await pdf_doc.embedPng(fimg);

        // Adds new pdf page
        const page = pdf_doc.addPage([embed_img.width, embed_img.height]);
        page.drawImage(embed_img, {x: 0, y: 0, width: embed_img.width, height: embed_img.height});
    }/* #> */

    // Cleaning
    fs.rmSync(SLIDES_FOLDER, {recursive: true, force: true});/* #< */
    console.log(`[INFO] '${SLIDES_FOLDER}' deleted...`);/* #> */

    // Pdf file
    const pdf_file = await pdf_doc.save();/* #< */
    fs.writeFileSync(OUTPUT_FILE, pdf_file);
    console.log(`PDF file saved at '${OUTPUT_FILE}'`);/* #> */

    /* #> */
})();

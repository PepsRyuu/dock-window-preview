let gui = require('gui');
let config = require('./config');

function bmp_img_encoder (img) {
    // http://www.ece.ualberta.ca/~elliott/ee552/studentAppNotes/2003_w/misc/bmp_file_format/bmp_file_format.htm
    let dataOffset = 54;
    let imageWidthSize =  4 * img.width;
    let buffer = new Buffer(dataOffset + img.height * imageWidthSize);
    
    let pos = 0;
    buffer.write('BM', pos, 2); pos += 2; // Signature
    buffer.writeUInt32LE(dataOffset + img.height * imageWidthSize, pos); pos += 4; // File Size
    buffer.writeUInt32LE(0, pos); pos += 4; // Reserved
    buffer.writeUInt32LE(dataOffset, pos); pos += 4; // DataOffset
    buffer.writeUInt32LE(40, pos); pos += 4; // InfoHeader Size
    buffer.writeUInt32LE(img.width, pos); pos += 4; // image width
    buffer.writeInt32LE(-img.height, pos); pos += 4; // image height, hack to ensure correct orientation
    buffer.writeUInt16LE(1, pos); pos += 2; // planes
    buffer.writeUInt16LE(32, pos); pos += 2; // Bits per Pixel
    buffer.writeUInt32LE(0, pos); pos += 4; // Compression (none)
    buffer.writeUInt32LE(img.height * imageWidthSize, pos); pos += 4; // Image Size
    buffer.writeUInt32LE(0, pos); pos += 4; // X Pixels Per Meter
    buffer.writeUInt32LE(0, pos); pos += 4; // Y Pixels Per Meter
    buffer.writeUInt32LE(0, pos); pos += 4; // Colors Used
    buffer.writeUInt32LE(0, pos); pos += 4; // Important Colors

    img.data.copy(buffer, pos);

    return buffer;
}

class Component {
    constructor(...args) {
        this.view = gui.Container.create();
        this.view.setMouseDownCanMoveWindow(false);
        this.view.onDraw = (self, painter) => this.onDraw(self, painter, self.getBounds(), config.get().theme);
        this.onInit(...args);
    }
}

module.exports = {
    bmp_img_encoder,
    Component
};
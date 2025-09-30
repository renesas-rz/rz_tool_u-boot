#include <common.h>
#include <cpu_func.h>
#include <image.h>
#include <init.h>
#include <malloc.h>
#include <netdev.h>
#include <dm.h>
#include <dm/platform_data/serial_sh.h>
#include <asm/processor.h>
#include <asm/mach-types.h>
#include <asm/io.h>
#include <linux/bitops.h>
#include <linux/errno.h>
#include <asm/arch/sys_proto.h>
#include <asm/gpio.h>
#include <asm/arch/gpio.h>
#include <asm/arch/renesas.h>
#include <asm/arch/rcar-mstp.h>
#include <asm/arch/sh_sdhi.h>
#include <i2c.h>
#include <mmc.h>
#include <dt-bindings/pinctrl/rzv2h-pinctrl.h>
#include <linux/delay.h>

DECLARE_GLOBAL_DATA_PTR;

#define PFC_BASE		0x10410000

#define P(x)			(PFC_BASE + 0x20 + PORT_##x)
#define PM(x)			(PFC_BASE + 0x140 + 2 * PORT_##x)
#define PMC(x)			(PFC_BASE + 0x220 + PORT_##x)
#define PFC(x)			(PFC_BASE + 0x0400 + 0x80 + 4 * PORT_##x)
#define	PFC_OSCBYPS		(PFC_BASE + 0x3C00)

#define PFC_PWPR		(PFC_BASE + 0x3C04)
#define PFC_PWPR_REGWE_A	BIT(6)
#define PFC_PWPR_REGWE_B	BIT(5)

#define PFC_OEN			(PFC_BASE + 0x3C40)
#define PFC_OEN_OEN0		BIT(0)
#define PFC_OEN_OEN1		BIT(1)

#define ICU_IPTSR_REG		0x10400060

#define SYS_ADC_CFG		0x10431600

#define CPG_BASE		0x10420000
#define CPG_SSEL0		(CPG_BASE + 0x0300)
#define CPG_SSEL1		(CPG_BASE + 0x0304)
#define CPG_SSEL(x)		(CPG_BASE + 0x300 + (x) * 4)
#define CPG_SSEL_WEN_L(x)	(BIT(16) << ((x) * 4))
#define CPG_SSEL_L(x)		(BIT(0) << ((x) * 4))
#define CPG_BUS_MSTOP(x)	(CPG_BASE + 0xD00 + (x) * 4 - 0x4)
#define CPG_LP_VSPI_CTL1	(CPG_BASE + 0xC9C)
#define CPG_LP_VSPI_CTL2	(CPG_BASE + 0xCA0)

#define PFC_PMC26		(PFC_BASE + 0x0226)
#define PFC_PFC26		(PFC_BASE + 0x0498)
#define PFC_PMC29		(PFC_BASE + 0x0229)
#define PFC_PFC29		(PFC_BASE + 0x04A4)
#define CPG_RST_USB		(CPG_BASE + 0x0928)
#define CPG_RSTMON4_USB		(CPG_BASE + 0x0A10)
#define CPG_RSTMON5_USB		(CPG_BASE + 0x0A14)
#define CPG_CLKON_USB		(CPG_BASE + 0x062C)
#define CPG_CLKMON_USB		(CPG_BASE + 0x0814)

/* USB */
#define USBPHY20_BASE		(0x15830000)
#define USBPHY21_BASE		(0x15840000)
#define USBPHY20_RESET		(USBPHY20_BASE + 0x000u)
#define USBPHY21_RESET		(USBPHY21_BASE + 0x000u)

#define USB20_BASE		(0x15800000)
#define USB21_BASE		(0x15810000)
#define USBF_BASE		(0x15820000)

#define COMMCTRL		0x800
#define HcRhDescriptorA		0x048
#define LPSTS			0x102
#define USB2_PHY_UTMICTRL2	0xb04
#define USB2_PHY_RESET		0x000
#define USB2_PHY_OTGR		0x600

void rzg3e_cpg_init_setting(void)
{
	/* Use CSDIV_2to16_PLLDSI for DSI0/1_VCLK */
	*(volatile u32 *)CPG_SSEL(3) = (CPG_SSEL_WEN_L(1) | CPG_SSEL_WEN_L(0) | CPG_SSEL_L(1) | CPG_SSEL_L(0));

	/* Release Module stop state for all needed IPs */
	*(volatile u32 *)CPG_BUS_MSTOP(1) = 0xCFFF0000;
	*(volatile u32 *)CPG_BUS_MSTOP(2) = 0xFCFF0000;
	*(volatile u32 *)CPG_BUS_MSTOP(3) = 0xFE7D0000;
	*(volatile u32 *)CPG_BUS_MSTOP(4) = 0x78AF0000;
	*(volatile u32 *)CPG_BUS_MSTOP(5) = 0xFFEA0000;
	*(volatile u32 *)CPG_BUS_MSTOP(6) = 0xFFFF0000;
	*(volatile u32 *)CPG_BUS_MSTOP(7) = 0x5F830000;
	*(volatile u32 *)CPG_BUS_MSTOP(8) = 0x18FC0000;
	*(volatile u32 *)CPG_BUS_MSTOP(9) = 0xFC100000;
	*(volatile u32 *)CPG_BUS_MSTOP(10) = 0xD8BE0000;
	*(volatile u32 *)CPG_BUS_MSTOP(11) = 0xFFFF0000;
	*(volatile u32 *)CPG_BUS_MSTOP(12) = 0x06030000;
	*(volatile u32 *)CPG_BUS_MSTOP(13) = 0x063F0000;

	/* For VSPI LPI initial setting */
	*(volatile u32 *)CPG_LP_VSPI_CTL1 = 0x01111111;
	*(volatile u32 *)CPG_LP_VSPI_CTL2 = 0x1;
}

void s_init(void)
{

	/* Enable writing to PFC and PMC registers */
       *(volatile u32 *)PFC_PWPR = *(volatile u32 *)PFC_PWPR | PFC_PWPR_REGWE_A | PFC_PWPR_REGWE_B ;

	/* Enable ADC */
	*(volatile u32 *)(SYS_ADC_CFG) = 0;

	/* QSD1 */
	*(volatile u8 *)PMC(1) &= ~(BIT(5) | BIT(6)); /* P1_5, P1_6 */
	*(volatile u8 *)P(1) = (*(volatile u8 *)P(1) & ~BIT(5)) | BIT(6); /* P1_5 = 0, P1_6 = 1 */
	*(volatile u16 *)PM(1) = (*(volatile u16 *)PM(1) & ~GENMASK(13, 10)) | BIT(13) | BIT(11); /* P1_5, P1_6 output */

	*(volatile u32 *)PFC(G) = 0x00111111;
	*(volatile u8 *)PMC(G)  = 0x3f;

	/* QSD2 */
	*(volatile u8 *)PMC(K) &= ~(BIT(1) | BIT(2)); /* PK_1, PK_2 */
	*(volatile u8 *)P(K) = (*(volatile u8 *)P(K) & ~BIT(1)) | BIT(2); /* PK_1 = 0, PK_2 = 1 */
	*(volatile u16 *)PM(K) = (*(volatile u16 *)PM(K) & ~GENMASK(5, 2)) | BIT(5) | BIT(3); /* PK_1, PK_2 output */

	*(volatile u32 *)PFC(H) = 0x00111111;
	*(volatile u8 *)PMC(H)  = 0x3f;

	/* ETH0 */
	*(volatile u8 *)PMC(A)  = 0x0f;
	*(volatile u32 *)PFC(A) = 0x00001111;
	*(volatile u8 *)PMC(B)  = 0xff;
	*(volatile u32 *)PFC(B) = 0x11111111;
	*(volatile u8 *)PMC(C)  = 0x07;
	*(volatile u32 *)PFC(C) = 0x00000111;

	/* ETH1 */
	*(volatile u8 *)PMC(D)  = 0x0f;
	*(volatile u32 *)PFC(D) = 0x00001111;
	*(volatile u8 *)PMC(E)  = 0xff;
	*(volatile u32 *)PFC(E) = 0x11111111;
	*(volatile u8 *)PMC(F)  = 0x07;
	*(volatile u32 *)PFC(F) = 0x00000111;

	/* Enale OE of IO block for xSPI */
	*(volatile u32 *)(PFC_OEN) &= ~GENMASK(5,2);

	*(volatile u32 *)(PFC_OEN) &= ~(PFC_OEN_OEN1 | PFC_OEN_OEN0);
	while((*(volatile u32 *)(PFC_OEN) & (PFC_OEN_OEN1 | PFC_OEN_OEN0)) != 0x0)

	/* Disable writing to PFC and PMC registers */
       *(volatile u32 *)PFC_PWPR = *(volatile u32 *)PFC_PWPR & ~(PFC_PWPR_REGWE_A | PFC_PWPR_REGWE_B);

       *(volatile u32 *)(ICU_IPTSR_REG) = 0;

	/* Disable SMUX2_GBE0_RXCLK and SMUX2_GBE1_RXCLK */
	*(volatile u32 *) (CPG_SSEL0) = 0x10000000;
	*(volatile u32 *) (CPG_SSEL1) = 0x00100000;

	/* Enable SMUX2_GBE0_RXCLK and SMUX2_GBE1_RXCLK */
	*(volatile u32 *) (CPG_SSEL0) = 0x10001000;
	*(volatile u32 *) (CPG_SSEL1) = 0x00100010;

       /* Set Bypass and Powerdown mode for Audio OSC */
#if CONFIG_TARGET_SMARC_RZG3E
	*(volatile u32 *)(PFC_OSCBYPS) = (*(volatile u32 *)(PFC_OSCBYPS) & 0xFFF3FC00) | 0x000C0003;
#else
	*(volatile u32 *)(PFC_OSCBYPS) = 0x000C0002;
#endif

	rzg3e_cpg_init_setting();
}

static void _usbphy_init(void)
{
	/* Overwrite SLEEPM/SUSPENDM signals by USB2PHY Control */
	(*(volatile u32 *)(USBPHY20_BASE + USB2_PHY_UTMICTRL2)) = 0x00000303;
	(*(volatile u32 *)(USBPHY21_BASE + USB2_PHY_UTMICTRL2)) = 0x00000303;

	/* Assert USB2PHY reset */
	(*(volatile u32 *)(USBPHY20_BASE + USB2_PHY_RESET)) = 0x00000206;
	(*(volatile u32 *)(USBPHY21_BASE + USB2_PHY_RESET)) = 0x00000206;

	/* Delay 10us */
	udelay(10);

	/* De-Assert USB2PHY reset */
	(*(volatile u32 *)(USBPHY20_BASE + USB2_PHY_RESET)) = 0x00000200;
	(*(volatile u32 *)(USBPHY21_BASE + USB2_PHY_RESET)) = 0x00000200;

	/* Release overwrites of SLEEPM/SUSMENDM signals, and RESET signal */
	(*(volatile u32 *)(USBPHY20_BASE + USB2_PHY_UTMICTRL2)) = 0x00000003;
	(*(volatile u32 *)(USBPHY20_BASE + USB2_PHY_RESET)) = 0;

	(*(volatile u32 *)(USBPHY21_BASE + USB2_PHY_UTMICTRL2)) = 0x00000003;
	(*(volatile u32 *)(USBPHY21_BASE + USB2_PHY_RESET)) = 0;

	/* Activate VBUS Valid comparator */
	(*(volatile u32 *)(USBPHY20_BASE + USB2_PHY_OTGR)) = 0x00000909;
	(*(volatile u32 *)(USBPHY21_BASE + USB2_PHY_OTGR)) = 0x00000909;
}

static void _reset_usb2(void)
{
	/* Reset for USBTEST */
	(*(volatile u32 *)CPG_RST_USB) |= 0x80008000;
	while((*(volatile u32 *)(CPG_RSTMON5_USB) & 0x00000001) != 0x0);

	/* Reset for USB2 host 0 and 1 */
	(*(volatile u32 *)CPG_RST_USB) |= 0x30003000;
	while((*(volatile u32 *)(CPG_RSTMON4_USB) & 0x60000000) != 0x0);
}

static void board_usb_init(void)
{
	/* Reset USB*/
	_reset_usb2();

	/* Enable clock for USB */
	(*(volatile u32 *)CPG_CLKON_USB) = 0x00F800F8;
	while((*(volatile u32 *)(CPG_CLKMON_USB) & 0x00F80000) != 0x00F80000);

	/* Setup  */
	/* Disable GPIO Write Protect */
	(*(volatile u32 *)PFC_PWPR) |= (0x1u << 6);

#if CONFIG_TARGET_SMARC_RZG3E
	/* Set P9_5 as Func.14 for VBUSEN */
	/* Control mode (multiplexed function) */
	(*(volatile u32 *)PFC_PMC29) |= (0x1u << 5);
	(*(volatile u32 *)PFC_PFC29) &= ~(0xF << 20);
	/* Function mode 15 */
	(*(volatile u32 *)PFC_PFC29) |= (0x0E << 20);

	/* Set P9_6 as Func.14 for OVRCUR */
	/* Control mode (multiplexed function) */
	(*(volatile u32 *)PFC_PMC29) |= (0x1u << 6);
	(*(volatile u32 *)PFC_PFC29) &= ~(0xF << 24);
	/* Function mode 14 */
	(*(volatile u32 *)PFC_PFC29) |= (0x0E << 24);

	/* Set P6_6 as Func.14 for VBUSEN */
	/* Control mode (multiplexed function) */
	 (*(volatile u32 *)PFC_PMC26) |= (0x1u << 6);
	 (*(volatile u32 *)PFC_PFC26) &= ~(0xF << 24);
	/* Function mode 14 */
	 (*(volatile u32 *)PFC_PFC26) |= (0x0E << 24);

	/* Set P6_7 as Func.14 for OVRCUR */
	/* Control mode (multiplexed function) */
	(*(volatile u32 *)PFC_PMC26) |= (0x1u << 7);
	(*(volatile u32 *)PFC_PFC26) &= ~(0xF << 28);
	/* Function mode 15 */
	(*(volatile u32 *)PFC_PFC26) |= (0x0E << 28);
#endif /* CONFIG_TARGET_SMARC_RZG3E */

	/* Enable Write protect */
	(*(volatile u32 *)PFC_PWPR) &= ~(0x1u << 6);

	/* Initialize phy */
	_usbphy_init();

	/*USB0 is HOST*/
	(*(volatile u32 *)(USB20_BASE + COMMCTRL)) = 0;

	/*USB1 is HOST*/
	(*(volatile u32 *)(USB21_BASE + COMMCTRL)) = 0;

	/* Set USBPHY normal operation (Function only) */
	(*(volatile u16 *)(USBF_BASE + LPSTS)) |= (0x1u << 14);

	/* Overcurrent is not supported */
	(*(volatile u32 *)(USB20_BASE + HcRhDescriptorA)) |= (0x1u << 12);
	(*(volatile u32 *)(USB21_BASE + HcRhDescriptorA)) |= (0x1u << 12);
}

int board_early_init_f(void)
{

	return 0;
}

int board_init(void)
{
	/* adress of boot parameters */
	gd->bd->bi_boot_params = CONFIG_TEXT_BASE + 0x50000;

	board_usb_init();

	return 0;
}

#if CONFIG_TARGET_SMARC_RZG3E
int board_late_init(void)
{
	struct udevice *dev;
	const u8 greenpak_i2c_bus = 8;
	const u8 greenpak_i2c_addr = 0x38;
	const u8 od_rst = 0x38;
	const u8 zero = 0;
	int ret;

	ret = i2c_get_chip_for_busnum(greenpak_i2c_bus, greenpak_i2c_addr, 1,
				      &dev);
	if (!ret) {
		dm_i2c_write(dev, 0x5c, &zero, 1);
		dm_i2c_write(dev, 0x5c, &od_rst, 1);
	}

	return 0;
}
#endif

void reset_cpu(void)
{

}

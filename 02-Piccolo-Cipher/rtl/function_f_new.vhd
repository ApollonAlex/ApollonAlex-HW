library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity function_f_new is
    port (
        data_in  : in  std_logic_vector(15 downto 0);
        data_out : out std_logic_vector(15 downto 0)
    );
end entity function_f_new;

architecture Structural of function_f_new is

    -- 4 nibbles (MSB-first): index 0 = bits 15..12, index 3 = bits 3..0
    type nibble_array is array (0 to 3) of std_logic_vector(3 downto 0);

    signal sbox1_out : nibble_array;
    signal v2_out    : nibble_array;
    signal v3_out    : nibble_array;
    signal mds_in    : nibble_array;
    signal sbox2_out : nibble_array;

    component sbox_4bit is
        port (
            input  : in  std_logic_vector(3 downto 0);
            output : out std_logic_vector(3 downto 0)
        );
    end component;

begin

    ----------------------------------------------------------------------------
    -- 1) First S-Box layer
    -- FIX: MSB-first nibble extraction
    ----------------------------------------------------------------------------
    gen_sbox1 : for i in 0 to 3 generate
        sb1 : sbox_4bit
            port map (
                input  => data_in(15 - 4*i downto 12 - 4*i),
                output => sbox1_out(i)
            );
    end generate;

    ----------------------------------------------------------------------------
    -- 2) GF(2^4) multiply by 2 and 3 (as in your original code)
    ----------------------------------------------------------------------------
    gen_mult : for i in 0 to 3 generate
        -- x2
        v2_out(i) <= (sbox1_out(i)(2 downto 0) & '0') xor "0011"
                     when sbox1_out(i)(3) = '1' else
                     (sbox1_out(i)(2 downto 0) & '0');

        -- x3 = x2 xor x1
        v3_out(i) <= v2_out(i) xor sbox1_out(i);
    end generate;

    ----------------------------------------------------------------------------
    -- 3) MDS (xor network)
    -- Row1: 2V0 + 3V1 + 1V2 + 1V3
    -- Row2: 1V0 + 2V1 + 3V2 + 1V3
    -- Row3: 1V0 + 1V1 + 2V2 + 3V3
    -- Row4: 3V0 + 1V1 + 1V2 + 2V3
    ----------------------------------------------------------------------------
    mds_in(0) <= v2_out(0) xor v3_out(1) xor sbox1_out(2) xor sbox1_out(3);
    mds_in(1) <= sbox1_out(0) xor v2_out(1) xor v3_out(2) xor sbox1_out(3);
    mds_in(2) <= sbox1_out(0) xor sbox1_out(1) xor v2_out(2) xor v3_out(3);
    mds_in(3) <= v3_out(0) xor sbox1_out(1) xor sbox1_out(2) xor v2_out(3);

    ----------------------------------------------------------------------------
    -- 4) Second S-Box layer
    -- FIX: MSB-first nibble placement back to data_out
    ----------------------------------------------------------------------------
    gen_sbox2 : for i in 0 to 3 generate
        sb2 : sbox_4bit
            port map (
                input  => mds_in(i),
                output => sbox2_out(i)
            );

        -- pack MSB-first
        data_out(15 - 4*i downto 12 - 4*i) <= sbox2_out(i);
    end generate;

end architecture Structural;


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity rp is
    port(
        X      : in  std_logic_vector(63 downto 0);
        rp_out : out std_logic_vector(63 downto 0)
    );
end rp;

architecture Behavioral of rp is
    signal X0, X1, X2, X3, X4, X5, X6, X7 : std_logic_vector(7 downto 0);
begin

    X0 <= X(63 downto 56);
    X1 <= X(55 downto 48);
    X2 <= X(47 downto 40);
    X3 <= X(39 downto 32);
    X4 <= X(31 downto 24);
    X5 <= X(23 downto 16);
    X6 <= X(15 downto 8);
    X7 <= X(7 downto 0);

    rp_out(63 downto 56) <= X2;
    rp_out(55 downto 48) <= X7;
    rp_out(47 downto 40) <= X4;
    rp_out(39 downto 32) <= X1;
    rp_out(31 downto 24) <= X6;
    rp_out(23 downto 16) <= X3;
    rp_out(15 downto 8)  <= X0;
    rp_out(7 downto 0)   <= X5;

end Behavioral;

